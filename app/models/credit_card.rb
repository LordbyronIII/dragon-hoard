class CreditCard
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Sequence

  field :number,   type: Integer
  field :month
  field :year
  field :ccv
  field :name

  belongs_to  :user
  belongs_to  :cart

  validates :number, presence: true
  validates :ccv, presence: true
  validates :name, presence: true
  validates :year, presence: true
  validate  :custom_validate
  
  def custom_validate
    errors.add(:number, "Number cannot be nil") unless self.ccv.present?
  end
end
