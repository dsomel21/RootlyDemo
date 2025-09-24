class Organization < ApplicationRecord
  has_one :slack_installation, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :slack_users, dependent: :destroy
  has_many :incidents, dependent: :destroy
  has_one :incident_counter, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    base_slug = normalize_slug_from_name(name)

    # Fail fast if the generated slug would conflict
    if Organization.exists?(slug: base_slug)
      raise ActiveRecord::RecordNotUnique,
            "Organization with slug '#{base_slug}' already exists. " \
            "Cannot auto-generate unique slug from name '#{name}'. " \
            "Please provide an explicit slug or use a different name."
    end

    self.slug = base_slug
  end

  def normalize_slug_from_name(name)
    return "" if name.blank?

    name.downcase
        .gsub(/[^a-z0-9\s\-]/, "") # Remove special characters except spaces and hyphens
        .gsub(/\s+/, "-")          # Replace spaces with hyphens
        .gsub(/-+/, "-")           # Replace multiple hyphens with single hyphen
        .strip                     # Remove leading/trailing whitespace
        .gsub(/^-+|-+$/, "")       # Remove leading/trailing hyphens
  end
end
