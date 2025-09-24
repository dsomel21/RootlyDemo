class IncidentCounter < ApplicationRecord
  self.primary_key = :organization_id
  belongs_to :organization

  validates :last_number, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.next_number_for_organization(organization)
    counter = find_or_create_by(organization: organization) { |c| c.last_number = 0 }
    counter.with_lock do
      counter.increment!(:last_number)
      counter.last_number
    end
  end
end
