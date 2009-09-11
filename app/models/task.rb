class Task < ActiveRecord::Base
  belongs_to :project
  belongs_to :user
  belongs_to :task_list
  belongs_to :page
  has_many :comments, :as => :target, :order => 'created_at DESC'
  
  attr_accessible :name

  def owner?(u)
    user = u
  end
  
  def before_save
    if position.nil?
      last_position = self.task_list.tasks.find(:first,
        :order => 'position DESC',
        :limit => 1)
      
      if last_position.nil?
        self.position = 1
      else
        self.position = last_position.position + 1
      end
      
    end
  end
end