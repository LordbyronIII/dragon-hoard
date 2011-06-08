class Admin::OrdersController < AdminController
  # before_filter :force_stage, :only => [:lookup, :address]
  before_filter :find_order, :only => [:show, :force_lookup, :refund, :address, :update, :print]
  before_filter :lookup_phone, :only => [:lookup]
  after_filter :clear_lookup_phone, :only => [:address, :cancel]
  # after_filter :force_stage, :only => [:new]
  def index
    @orders = params[:find] ? Order.send(params[:find].to_sym).paginate(pagination_hash) : Order.payments_made.paginate(pagination_hash)
  end
  
  def new
    staging_type = params[:staging_type] ? params[:staging_type] : "purchase"
    location = params[:location] ? params[:location] : "instore"
    
    case staging_type
    when "repair"
      due_at = "3 weeks"
    when "custom"
      due_at = "6 weeks"
    end
    
    session_order = Order.create(:location => location, :staging_type => staging_type, :handed_off => false, :clerk_id => @current_user.id, :due_at => due_at)
    session[:customer_order_id] = session_order.id
    
    current_customer_order.ticket.current_stage = "customer lookup"
  end
  
  def force_lookup
    flash[:error] = "We don't have any customer info for this order. Please lookup a customer"
    current_customer_order.ticket.current_stage = "customer lookup"
    render :template => "admin/orders/new"
  end
  
  def lookup
    phone = flatten_phone(params[:user][:phone])
    @customers = User.find(:all, :conditions => {:phone => phone})
    redirect_to address_admin_order_path(@order) + "?user[phone]=#{phone}" unless @customers.length > 0
  end
  
  def address
    if params[:customer_id]
      customer = User.find(params[:customer_id])
      address = customer.addresses.last
      current_customer_order.update_attributes :user_id => customer.id
      current_customer_order.update_attributes :address_1 => address.address_1, :address_2 => address.address_2, :city => address.city, :province => address.province, :country => address.country, :postal_code => address.postal_code if params[:address]
    end
    if session[:lookup_phone] or params[:user]
      lookup_phone
    end
    current_customer_order.ticket.current_stage = "addressing"
  end
  
  def cancel
    current_customer_order.clear
    current_customer_order.delete
    session[:customer_order_id] = nil
    redirect_to admin_root_path
  end
  
  def create
  end
  
  def update
    params[:order].delete("shipping_option") unless params[:order][:ship]
    @order = Order.find(params[:id])
    @order.update_attributes params[:order]
    redirect_to admin_order_path(@order)
  end
  
  def refund
    @order = Order.find(params[:id])
    customer = @order.user
    payments = @order.paid
    if @order.refund
      flash[:notice] = "Order #{params[:id]} has been refunded."
      flash[:important] = "There is a balance of $#{payments} owed to #{customer.name}."
    else
      flash[:error] = "There was an error refunding this order. Please try again."
    end
    redirect_to admin_order_path(params[:id])
  end
  
  def show
    @order = Order.find(params[:id])
    
    session[:customer_order_id] = @order.id if @order
    
    current_customer_order.update_attributes :clerk => @current_user unless current_customer_order.clerk_id != nil
    
    unless @order.has_valid_shipping_address?
      redirect_to address_admin_order_path(@order) and return
    else
      render :template => "admin/orders/show_#{@order.location}_#{@order.staging_type}"
    end
  end
  
  def print
    template = "admin/orders/print_#{@order.location}_#{@order.staging_type}"
    render :template => template, :layout => "print"
  end
  
  def find
    begin
      order = Order.find(params[:order])
      flash[:notice] = "Order ##{order.id} is now in use. We have saved your previous or with an id of ##{current_customer_order.id}."
      switch_current_customer_order(order.id)
      redirect_to admin_order_path(order) and return
    else
      flash[:error] = "We could not find an order with the id of ##{params[:order]}. Please make sure the order number is valid and try again."
      redirect_to :back and return
    end
  end
  
  def destroy
  end
  
  private
    def switch_current_customer_order(order_id)
      current_customer_order.save!
      session[:customer_order_id] = order_id
      current_customer_order
    end
    
    def hand_off_order
      current_customer_order.line_items.the_living.each do |line_item|
        item = line_item.variation.item
        line_item.variation.update_attributes :quantity => line_item.variation.quantity - 1 if line_item.variation.quantity > 0
        if item.one_of_a_kind
          item.update_attributes :available => false, :published => false
        end
      end
      current_customer_order.update_attributes :handed_off => true, :ghost => true
      session[:customer_order_id] = nil
    end
    
    # phase out
    # def current_stage
    #   stage = ""
    #   if current_customer_order.payments.length > 0
    #     stage = admin_order_payments_path(@order)
    #   else
    #     stage = admin_order_line_items_path(@order)
    #   end
    #   return stage
    # end
    
    def lookup_phone
      @lookup_phone = session[:lookup_phone] ? session[:lookup_phone] : params[:user][:phone]
      session[:lookup_phone] = @lookup_phone
      return @lookup_phone
    end
    
    def clear_lookup_phone
      session[:lookup_phone] = nil
    end
    
    def flatten_phone(phone)
      new_phone = phone.gsub("(","").gsub(")","").gsub("-","").gsub(",","").gsub(".","").gsub(" ","").gsub("+","")
      new_phone.insert(3,"-").insert(7,"-")
      return new_phone
    end
    
    def force_customer
      logger.debug "-- address => #{current_customer_order.address.inspect}"
      unless current_customer_order.address
        session[:force_customer] = "true"
        redirect_to force_lookup_admin_order_path(current_customer_order) and return
      else
        session[:force_customer] = nil
      end
    end
end
