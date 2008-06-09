class Entity < Sequel::Model
  one_to_many :entries
  one_to_many(:recent_entries, :class_name=>'Entry', :eager=>[:credit_account, :debit_account, :entity], :order=>:date.desc){|ds| ds.limit(25)}
  @scaffold_fields = [:name]
  @scaffold_select_order = :name
  @scaffold_associations = [:recent_entries]
  @scaffold_auto_complete_options = {}
  @scaffold_session_value = :user_id
  
  def scaffold_name
    name[0..30]
  end
end
