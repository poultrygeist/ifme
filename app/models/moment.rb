# frozen_string_literal: true
# == Schema Information
#
# Table name: moments
#
#  id                      :bigint(8)        not null, primary key
#  category                :text
#  name                    :string
#  mood                    :text
#  why                     :text
#  fix                     :text
#  created_at              :datetime
#  updated_at              :datetime
#  user_id                 :integer
#  viewers                 :text
#  comment                 :boolean
#  strategy                :text
#  slug                    :string
#  secret_share_identifier :uuid
#  secret_share_expires_at :datetime
#  published_at            :datetime
#

class Moment < ApplicationRecord
  include Viewer
  include CommonMethods
  extend FriendlyId

  friendly_id :name
  serialize :category, Array
  serialize :viewers, Array
  serialize :mood, Array
  serialize :strategy, Array

  before_save :category_array_data
  before_save :viewers_array_data
  before_save :mood_array_data
  before_save :strategy_array_data

  belongs_to :user

  has_many :comments, as: :commentable
  has_many :moments_moods
  has_many :moods, through: :moments_moods

  validates :comment, inclusion: [true, false]
  validates :user_id, :name, :why, presence: true
  validates :why, length: { minimum: 1 }
  validates :secret_share_expires_at,
            presence: true, if: :secret_share_identifier?

  scope :published, -> { where.not(published_at: nil) }
  scope :recent, -> { order('created_at DESC') }

  def self.find_secret_share!(identifier)
    find_by!(
      # 'secret_share_expires_at > NOW()', TODO: Turn off temporarily
      secret_share_identifier: identifier
    )
  end

  def self.populate_moments_moods
    Moment.all.find_each do |moment|
      moment.mood = Mood.where(id: moment.mood).pluck(:id)
      moment.save
    end
  end

  def category_array_data
    self.category = category.collect(&:to_i) if category.is_a?(Array)
  end

  def viewers_array_data
    self.viewers = viewers.collect(&:to_i) if viewers.is_a?(Array)
  end

  def mood_array_data
    mood_ids = mood.collect(&:to_i)
    self.mood = mood_ids if mood.is_a?(Array)
    self.moods = Mood.where(user_id: user_id, id: mood_ids) if mood.is_a?(Array)
  end

  def strategy_array_data
    self.strategy = strategy.collect(&:to_i) if strategy.is_a?(Array)
  end

  def owned_by?(user)
    user&.id == user_id
  end

  def published?
    published_at.present?
  end

  def shared?
    secret_share_identifier?
    # && Time.zone.now < secret_share_expires_at TODO: Turn off temporarily
  end

  def comments
    Comment.comments_from(self)
  end
end
