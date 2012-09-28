class Cart
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Sequence
  
  field :first_name
  field :last_name
  field :email
  field :phone
  field :current_stage

  belongs_to  :user
  embeds_many :line_items
  embeds_one  :shipping_address#, cascade_callbacks: true

  validates :email, presence: true, format: {with: /^\w+[\w\+\-.]+@[\w\-.]+.[\w]{2,4}$/, message: "%{value} is not a proper email"}, if: 'current_stage.present?'

  validates :phone, presence: true, if: 'current_stage.present?'
  validates :first_name, presence: {message: "First Name can't be blank"}, if: 'current_stage.present?'
  validates :last_name, presence: {message: "Last Name can't be blank"}, if: 'current_stage.present?'
end
