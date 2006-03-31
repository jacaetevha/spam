class Entity < ActiveRecord::Base
  has_many :entries
  has_many :recent_entries, :class_name=>'Entry', :include=>[:credit_account, :debit_account, :entity], :limit=>25, :order=>'date DESC'
  @scaffold_fields = %w'name'
  @scaffold_select_order = 'name'
  @scaffold_associations = %w'recent_entries'
  def scaffold_name
    name[0..30]
  end
end
