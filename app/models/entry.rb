class Entry < Sequel::Model
  many_to_one :credit_account, :class_name=>'Account', :key=>:credit_account_id
  many_to_one :debit_account, :class_name=>'Account', :key=>:debit_account_id
  many_to_one :entity
  
  @scaffold_fields = [:date, :reference, :entity, :credit_account, :debit_account, :amount, :memo, :cleared]
  @scaffold_select_order = [:date.desc, :reference.desc, :amount.desc]
  @scaffold_include = [:entity, :credit_account, :debit_account]
  @scaffold_auto_complete_options = {:sql_name=>"reference || date::TEXT || entities.name ||  accounts.name || debit_accounts_entries.name || entries.amount::TEXT"}
  @scaffold_session_value = :user_id
  
  def self.user(user_id)
    filter(:user_id=>user_id)
  end
  
  def scaffold_name
    "#{date.strftime('%Y-%m-%d')}-#{reference}-#{entity.name if entity}-#{debit_account.name if debit_account}-#{credit_account.name if credit_account}-#{money_amount}"
  end
  
  attr_accessor :other_account
  
  def income
    self[:income].to_money
  end
  
  def expense
    self[:expense].to_money
  end
  
  def profit
    (self[:income].to_f - self[:expense].to_f).to_money
  end
  
  def money_amount
    amount.to_money
  end
  
  def main_account=(account)
    @other_account = if account.id == credit_account_id
      self[:amount] *= -1 if amount
      debit_account
    else
      credit_account
    end
  end
end
