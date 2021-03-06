class Schedule < ActiveRecord::Base
  belongs_to :user
  belongs_to :room
  has_many :schedule_users
  has_many :members, class_name: "User",
    through: :schedule_users,  foreign_key: :schedule_id

  validates :title, presence: true, length: {maximum: 150}
  validates :start_time, presence: true
  validates :finish_time, presence: true
  validates :description, presence: true, length: {maximum: 450}
  validates :room, presence: true
  validates :user, presence: true
  validate :valid_time, :valid_room

  scope :with_room, ->(room, id){where(room: room).where.not id: id}
  query = "(start_time <= :start_time AND finish_time >= :finish_time)
          OR (start_time > :start_time AND start_time < :finish_time)
          OR (finish_time > :start_time AND finish_time < :finish_time)"
  scope :filte_timer, ->(start, finish){where(query, start_time: start, finish_time: finish)}
  scope :today_schedule, ->{where("start_time LIKE ?", "%#{Time.now.to_date.to_s}%")}
  scope :filter_by_room, ->(room_id){where room_id: room_id if room_id.present? && room_id != "all"}

  accepts_nested_attributes_for :members

  delegate :name, to: :room, prefix: true
  delegate :color, to: :room, prefix: true

  after_create :notification_users

  def min_json
    {
      id: id,
      title: title,
      start_time: start_time,
      finish_time: finish_time,
      user_id: user_id,
      room_name: room_name,
      room_color: room_color
    }
  end

  private
  def valid_room
    if Schedule.with_room(room_id, id).filte_timer(start_time, finish_time).count > 0
      errors.add :room, I18n.t('valid_room')
    end
  end

  def valid_time
    if !start_time.blank? && !finish_time.blank? && start_time >= finish_time
      errors.add :start_time, I18n.t('valid_time')
    end
  end

  def notification_users
    members.each {|member| UserMailer.invite_email(member, self).deliver_now}
  end
end
