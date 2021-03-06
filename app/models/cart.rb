class Cart
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Sequence
  
  field :first_name
  field :last_name
  field :email
  field :phone
  field :current_stage
  field :shipping_type

  attr_accessor :shipping_address_id

  has_one     :order
  belongs_to  :user
  embeds_many :line_items
  embeds_one  :payment
  has_one     :credit_card
  embeds_one  :shipping_address
  embeds_one  :billing_address

  accepts_nested_attributes_for :line_items, :billing_address, :credit_card

  validates :email, presence: true, format: {with: /^\w+[\w\+\-.]+@[\w\-.]+.[\w]{2,4}$/, message: "%{value} is not a proper email"}, if: :current_stage_progressing

  validates :phone, presence: true, format: {with: /^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[ ]?[-. ]?[ ]?([0-9]{4})$/, message: "%{value} is not a proper phone number. Example: (231)775-1289"}, if: :current_stage_progressing
  validates :first_name, presence: true, if: :current_stage_progressing
  validates :last_name, presence: true, if: :current_stage_progressing

  before_save :set_shipping_address

  def handling
    return 5
  end

  def process_cart
    order = create_order_from_cart
    # TODO: process_payments
    # status = order.process_payments(use_payment_processor: true)
    status = 'ok'
    if status == 'ok'
      self.current_stage = 'summary'; save
      return self
    else
      # TODO: add errors to base
      return self
    end
  end

  def create_order_from_cart
    self.order = Order.create(
      user:             self.user,
      line_items:       self.line_items,
      address:          self.shipping_address,
      shipping_option:  self.shipping_type,
      location:         'website'
    )

    invoice = self.order.invoices.create(amount: self.total)
    invoice.add_payment(payment_type: 'credit_card', processed: false, amount: self.total)
    return self.order
  end
  
  def full_name
    first_name + ' ' + last_name
  end

  def add_item(item, options={})
    line_items.create(options.merge!(item: (item.is_a?(Item) ? item : Item.find(item))))
  end

  def shipping_options
    Shipper.rates(Shipper.destination(shipping_address), Shipper.sample_packages)
  end

  def ups_shipping_options
    fedex_rates = shipping_options
    ups_rates = Shipper.get_ups_rate(self.shipping_address, Shipper.sample_packages)
    ups_rates_hash = {}
    ups_rates.each do |rate|
      ups_rates_hash[rate[0].to_s] = (rate[1].to_f / 100).to_s
    end
    
    fedex_rates + ups_rates.collect {|rate| {name: rate[0], total_net_charge: (rate[1].to_f / 100).to_s}}
  end

  def individual_ups_rate
    ups_rates = Shipper.get_ups_rate(self.shipping_address, Shipper.sample_packages)

    ups_rates.each do |rate|
      if rate[0].upcase == shipping_type.upcase
        return rate[1]
      end
    end
  end

  def shipping_rate
    shipping_options[shipping_type.to_sym][:price]
  end

  def tax
    (line_items.where(taxable: true).map(&:total).sum * 0.06).round(2)
  end
  
  def subtotal
    (line_items.map(&:total).sum).round(2)
  end

  def total
    total = subtotal + tax + shipping_options[shipping_type.to_sym][:price]
  end

  private
    def current_stage_progressing
      exclude_stages = ['show', 'checkout']
      current_stage.present? && !exclude_stages.include?(current_stage)
    end

    def set_shipping_address
      return true unless shipping_address_id

      address = User.all
        .map(&:addresses).flatten.compact
        .select do |address|
          address.id.to_s == shipping_address_id
        end.first
      self.shipping_address = address.clone if address
    end
end
