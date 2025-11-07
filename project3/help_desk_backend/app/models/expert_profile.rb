class ExpertProfile < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :user_id, uniqueness: true
  validates :bio, length: { maximum: 2000 }, allow_nil: true
  
  attribute :knowledge_base_links, :json, default: {}

end
