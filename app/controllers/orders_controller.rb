class OrdersController < ApplicationController
  before_filter :force_login
  before_filter :"has_shipping_address?",         only:   [:checkout, :pay, :complete]
  before_filter :carry_over_order_notes,          only:   [:checkout, :pay, :complete]
  
  def show
    @order = current_order
  end
  
  def update
    @order = User.find_order(params[:id])
    
    if params[:order][:line_items].present?
      line_items = params[:order].delete(:line_items) 

      line_items.each do |line_item|
        @order.line_items[line_item[0].to_i].update_attributes line_item[1]
      end

      @order.save
    end

    if @order.update_attributes params[:order]
     if params[:"checkout-order"] == "true"
        redirect_to checkout_path and return
      else
        flash[:notice] = "Your order has been updated"
        redirect_to order_path(@order.pretty_id) and return
      end
    else
      flash[:error] = "We could not update your order"
      render :action => "show"
    end
  end
  
  def checkout
    @order = current_order
    redirect_to order_path(current_order.pretty_id) unless @order.line_items.length > 0
  end
  
  def shipping
    @order = current_order
    redirect_to order_path(current_order.pretty_id) unless @order.line_items.length > 0
  end
  
  def addressed
    @updated_order = current_order
    address_hash = params[:address]
    address = current_user.addresses.where(address_hash)
    address = address.present? ? address.first : current_user.addresses.create(address_hash)
    @updated_order.address = address.clone
    @updated_order.save
    flash[:notice] = "Your shipping address has been added. Thank you."
    redirect_to checkout_path(@updated_order.pretty_id)
  end
  
  def pay
    @order = current_order    

    if (params[:order] && params[:order][:line_items].present?)
      line_items = params[:order].delete(:line_items) 

      line_items.each do |line_item|
        @order.line_items[line_item[0].to_i].update_attributes line_item[1]
      end

      @order.save
    end

    @order.update_attributes params[:address]
    @order.update_attributes params[:order]
  end
  
  def complete
    # -- Validate Credit Card Fields --
    card_validation_errors = []
    if params[:card]
      %w(cardholder_name expiration_month expiration_year number).each do |field|
        test_field = params[:card][:"#{field}"]
        unless test_field && test_field != nil && test_field != ""
          card_validation_errors << "The #{field.split('_').join(" ")} was not filled out properly. Please fill it out and try again."
        end
      end
    else
      card_validation_errors << "You need to fill out the credit card form in order to purchase"
    end
    # --
    
    if card_validation_errors.length < 1
      
      first_name, last_name = params[:card][:cardholder_name].split(" ")
      expiration_date       = "#{params[:card][:expiration_month]}/#{params[:card][:expiration_year]}"
      card = {
        credit_card: {
          number:          params[:card][:number],
          expiration_date: "#{params[:card][:expiration_month]}/#{params[:card][:expiration_year]}"
        },
        customer: {
          first_name: first_name,
          last_name:  last_name
        },
        amount: current_order.total.to_i
      }
      
      @result = Braintree::Transaction.sale(card)
      logger.debug "\n\n== @result => #{@result.inspect}\n\n"
      if @result.success?
        transaction = @result.transaction
        current_order.payments.create(payment_type: transaction.credit_card_details.card_type.downcase, amount: current_order.total.to_i)
        current_order.save
        @finished_order = current_order
        hand_off_order
        @order = current_order

        # TODO: Upgrade current mailers
        # UserMailer.deliver_order_completed(@finished_order.user, @finished_order)

        render :template => "orders/complete"
      elsif @result.transaction
        @order = current_order
        flash[:error] = "<p class='error'>#{@result.transaction.processor_response_text} (##{@result.transaction.processor_response_code})</p>"
        render template: "orders/pay"
      else
        @order = current_order
        flash[:error] = ""
        @result.errors.each do |e|
          flash[:error] += "<p class='error'>#{e.message}</p>"
        end
        render template: "orders/pay"
      end
    else
      
      @order = current_order
      flash[:message] = ""
      
      card_validation_errors.each do |message|
        flash[:message] += "<p class='error'>#{message}</p>"
      end
      
      render template: "orders/pay"
    end
  end
  
  def clear
    current_order.line_items.each {|line_item| line_item.destroy}
    redirect_to order_path(current_order.pretty_id)
  end
  
  private
    def ssl_allowed?
      case action_name
      when "show"
        return true
      when "clear"
        return true
      else
        return false
      end
    end
    
    def has_shipping_address?
      if current_order.has_valid_shipping_address?
        return true
      else
        redirect_to shipping_path, :method => :post
      end
    end
    
    def carry_over_order_notes
      begin
        current_order.update_attributes :notes => params[:order][:notes]
      ensure
        return true
      end
    end
    
    def hand_off_order
      order = current_order
      order.update_attributes :purchased_at => Time.now
      order.hand_off
    end
    
end
