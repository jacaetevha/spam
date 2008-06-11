#!/usr/bin/env spec
require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'net/http'
$:.unshift "/home/jeremy/sequel/sequel/lib"
$:.unshift "/home/jeremy/sequel/sequel_core/lib"
require 'sequel'

DB = Sequel.postgres('spamtest', :user=>'guest', :host=>'/tmp')
Entries = DB[:entries].filter(:user_id => 1)
Entries.delete
DB[:entities].filter(:id > 4).delete
DB[:accounts].filter(:id > 6).delete
HOST = 'www'
PORT = 8989

module Hpricot::Traverse
  alias ih inner_html
  alias it inner_text
  def hc
    children.reject{|x| Hpricot::Text === x}
  end
end
class Hpricot::Elements
  def maphr
    collect{|x| x[:href]}
  end
  def mapit
    collect{|x| x.it}
  end
  def maptype
    collect{|x| x.name}
  end
  def mapname
    collect{|x| x[:name]}
  end
  def mapvalue
    collect{|x| x[:value]}
  end
end

def http_url(path)
  "http://#{HOST}:#{PORT}#{path}"
end

def page(path)
  f = open(http_url(path))
  h = Hpricot(f) 
  f.close
  h
end

def post(path, params)
  req = Net::HTTP::Post.new(path)
  req.set_form_data(params)
  Net::HTTP.new(HOST, PORT).start{|http| http.request(req)}
end

def post_xhr(path, params)
  req = Net::HTTP::Post.new(path)
  req.set_form_data(params)
  req['Accept'] = "text/javascript, text/html, application/xml, text/xml, */*"
  req['X-Requested-With'] = 'XMLHttpRequest'
  Net::HTTP.new(HOST, PORT).start{|http| http.request(req)}
end

def remove_id(hash)
  h = hash.dup
  h.delete(:id)
  h
end

describe "$PAM home page" do
  it "should have correct CSS, Javascript, and Navigation links" do 
    p = page('')
    p.at(:title).ih.should == '$PAM - Login'
    (p/:link).collect{|x| x[:href].gsub(/\A\/stylesheets\/(.*)\.css\?\d*\z/, '\1')}.should == %w'spam scaffold_associations_tree'
    (p/:script).collect{|x| x[:src].gsub(/\A\/javascripts\/(.*)\.js\?\d*\z/, '\1')}.should == %w'prototype effects dragdrop controls application scaffold_associations_tree'
    (p/"div#nav a").maphr.should == %w'/ /update/register/1 /update/register/2 /update/reconcile/1 /update/reconcile/2 /reports/balance_sheet /reports/earning_spending /reports/income_expense /reports/net_worth /update/manage_account /update/manage_entity /update/manage_entry /login/change_password'
  end
end

describe "$PAM register page" do
  def check_entry_row(row, skip_value = false)
    fields = row/"td"/"input, select"
    fields.maptype.should == %w'input input input select input input input'
    fields.mapname.should == %w'entry[date] entry[reference] entity[name] account[id] entry[memo] entry[amount]' << nil
    fields.mapvalue.should == [Date.today.to_s, '', '', nil, '', '', 'Add'] unless skip_value
    opts = fields/"option"
    opts.mapit.should == '/Checking/Credit Card/Food/Salary'.split('/')
    opts.mapvalue.should == [nil, '1', '2', '4', '3']
  end

  it "should have a correct form and table" do 
    p = page('/update/register/1')
    p.at(:title).ih.should == '$PAM - Checking Register'
    p.at(:h3).ih.should == 'Showing 35 Most Recent Entries'
    form = p.at(:form)
    form[:action].should == '/update/add_entry'
    input = (form/:input)
    input.length.should == 8
    hidden = input[0..1]
    hidden.mapname.should == %w'selected_entry_id register_account_id'
    hidden.mapvalue.should == [nil, '1']
    (form/:tr).length.should == 2
    (form/"table thead tr th").mapit.should == 'Date/Num/Entity/Other Account/Memo/C/Amount/Balance/Modify'.split('/')
    check_entry_row((form/"table tbody tr").first)
  end

  it "should add entries the non-Ajax way" do
    res = post('/update/add_entry', "register_account_id"=>'1', "entry[date]"=>'2008-06-06', 'entry[reference]'=>'DEP', 'entity[name]'=>'Employer', 'account[id]'=>'3', 'entry[memo]'=>'Check', 'entry[amount]'=>'1000')
    res['Location'].should == http_url('/update/register/1')
    entry = Entries.first
    remove_id(entry).should == {:date=>'2008-06-06'.to_date, :reference=>'DEP', :entity_id=>1, :credit_account_id=>3, :debit_account_id=>1, :memo=>'Check', :amount=>'1000'.to_d, :cleared=>false, :user_id=>1}

    p = page('/update/register/1')
    tr = (p/"form table tbody tr")
    tr.length.should == 2
    (tr.first/:td)[-2].it.should == '$1000.00'
    check_entry_row(tr.first)
    tr = tr.last
    td = tr/:td
    td.mapit.should == '2008-06-06/DEP/Employer/Salary/Check//$1000.00/$1000.00/Modify'.split('/')
    td.at(:a)[:href].should == "/update/modify_entry/#{entry[:id]}?register_account_id=1"
  end

  it "should modify entries the non-Ajax way" do
    entry = Entries.first
    p = page("/update/modify_entry/#{entry[:id]}?register_account_id=1")
    tr = (p/"form table tbody tr")
    tr.length.should == 2
    (tr.first/:td).mapit.should == '///////$1000.00/Add'.split('/')
    (tr.first/:td)[-2].it.should == '$1000.00'
    tr = tr.last
    fields = tr/"td"/"input, select"
    fields.maptype.should == %w'input input input select input input input input input input'
    fields.mapname.should == %w'entry[date] entry[reference] entity[name] account[id] entry[memo] entry[cleared] entry[cleared] entry[amount] entry[id] update'
    fields.mapvalue.should == ['2008-06-06', 'DEP', 'Employer', nil, 'Check', '1', '0', '1000.0', entry[:id].to_s, 'Update']
    (fields/:option)[4][:selected].should == 'selected'

    res = post('/update/add_entry', "update"=>"Update", "register_account_id"=>'1', "entry[date]"=>'2008-06-07', 'entry[reference]'=>'1000', 'entity[name]'=>'Card', 'account[id]'=>'2', 'entry[memo]'=>'Payment', 'entry[amount]'=>'-1000', 'entry[cleared]'=>'1', 'entry[id]'=>entry[:id].to_s)
    res['Location'].should == http_url('/update/register/1')
    entry2 = Entries[:id => entry[:id]]
    entry2.should == {:date=>'2008-06-07'.to_date, :reference=>'1000', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>'1000'.to_d, :cleared=>true, :user_id=>1, :id=>entry[:id]}

    p = page('/update/register/1')
    tr = (p/"form table tbody tr")
    tr.length.should == 2
    check_entry_row(tr.first, true)
    (tr.first/:td)[-2].it.should == '$-1000.00'
    tr = tr.last
    td = tr/:td
    td.mapit.should == '2008-06-07/1000/Card/Credit Card/Payment/R/$-1000.00/$-1000.00/Modify'.split('/')
  end

  it "should add entries the Ajax way" do
    Entries.delete
    res = post_xhr('/update/add_entry', "register_account_id"=>'1', "entry[date]"=>'2008-06-06', 'entry[reference]'=>'DEP', 'entity[name]'=>'Employer', 'account[id]'=>'3', 'entry[memo]'=>'Check', 'entry[amount]'=>'1000')
    res['Content-Type'].should =~ /javascript/
    entry = Entries.first
    remove_id(entry).should == {:date=>'2008-06-06'.to_date, :reference=>'DEP', :entity_id=>1, :credit_account_id=>3, :debit_account_id=>1, :memo=>'Check', :amount=>'1000'.to_d, :cleared=>false, :user_id=>1}
  end

  it "should modify entries the Ajax way" do
    entry = Entries.first
    res = post_xhr('/update/add_entry', "update"=>"Update", "selected_entry_id"=>entry[:id].to_s, "register_account_id"=>'1', "entry[date]"=>'2008-06-07', 'entry[reference]'=>'1000', 'entity[name]'=>'Card', 'account[id]'=>'2', 'entry[memo]'=>'Payment', 'entry[amount]'=>'-1000', 'entry[cleared]'=>'0', 'entry[id]'=>entry[:id].to_s)
    res['Content-Type'].should =~ /javascript/
    entry2 = Entries[:id => entry[:id]]
    entry2.should == {:date=>'2008-06-07'.to_date, :reference=>'1000', :entity_id=>3, :credit_account_id=>1, :debit_account_id=>2, :memo=>'Payment', :amount=>'1000'.to_d, :cleared=>false, :user_id=>1, :id=>entry[:id]}
  end

  it "should auto complete entity names" do
    (Hpricot(post('/update/auto_complete_for_entity_name', 'entity[name]'=>'%').body)/:li).mapit.should == %w'Card Employer Restaurant'
    (Hpricot(post('/update/auto_complete_for_entity_name', 'entity[name]'=>'z').body)/:li).length.should == 0
  end
end

describe "$PAM reconcile page" do
  it "should have correct form and table" do
    p = page('/update/reconcile/1')
    form = p.at(:form)
    form[:action].should == '/update/clear_entries/1'
    tables = form/:table
    tables.length.should == 3
    table = tables.first
    tr = table/:tr
    tr.length.should == 5
    td = tr/:td
    td.length.should == 9
    td.mapit.should == "Unreconciled Balance/$0.00/Reconciling Changes/$0.00/Reconcile To//Off By/$0.00/\n  \n  \n".split('/')
    td[5].at(:input)[:value].should == '$0.00'
    input = td.last/:input
    input.mapvalue.should == 'Auto-Reconcile/Clear Entries'.split('/')
    input.mapname.should == 'auto_reconcile/clear_entries'.split('/')
    tables.shift
    (tables/:caption).mapit.should == 'Debit Entries/Credit Entries'.split('/')
    tables.each{|t| (t/"thead tr th").mapit.should == %w'C Date Num Entity Amount'}
    (tables.first/"tbody tr td").length.should == 0
    td = tables.last/"tbody tr td"
    td.mapit.should == '/2008-06-07/1000/Card/$1000.00'.split('/')
    cb = td.first.at(:input)
    cb[:name].should == "entries[#{Entries.first[:id]}]"
    cb[:value].should == "1"
  end

  it "should auto reconcile the non-Ajax way" do
    entry = Entries.first
    entry[:cleared].should == false
    res = post('/update/clear_entries/1', "auto_reconcile"=>"Auto-Reconcile", "reconcile_to"=>"-1000.00", "entries[#{entry[:id]}]"=>"1")
    Hpricot(res.body).at("input#credit_#{entry[:id]}")[:checked].should == 'checked'
  end

  it "should clear entries the non-Ajax way" do
    entry = Entries.first
    entry[:cleared].should == false
    res = post('/update/clear_entries/1', "clear_entries"=>"Clear Entries", "reconcile_to"=>"-1000.00", "entries[#{entry[:id]}]"=>"1")
    res['Location'].should == http_url('/update/reconcile/1')
    Entries.first[:cleared].should == true
    p = page('/update/reconcile/1')
    p.at("input#credit_#{entry[:id]}").should == nil
    (p.at(:table)/:td).mapit.should == "Unreconciled Balance/$-1000.00/Reconciling Changes/$0.00/Reconcile To//Off By/$-1000.00/\n  \n  \n".split('/')
  end

  it "should auto reconcile the Ajax way" do
    Entries.update(:cleared=>false)
    entry = Entries.first
    entry[:cleared].should == false
    res = post_xhr('/update/auto_reconcile/1', "auto_reconcile"=>"Auto-Reconcile", "reconcile_to"=>"-1000.00", "entries[#{entry[:id]}]"=>"1")
    res['Content-Type'].should =~ /javascript/
  end

  it "should clear entries the Ajax way" do
    entry = Entries.first
    entry[:cleared].should == false
    res = post_xhr('/update/clear_entries/1', "auto_reconcile"=>"Auto-Reconcile", "reconcile_to"=>"-1000.00", "entries[#{entry[:id]}]"=>"1")
    res['Content-Type'].should =~ /javascript/
    Entries.first[:cleared].should == true
  end
end

describe "$PAM reports" do
  it "balance sheet should be correct" do
    cells = (page('/reports/balance_sheet').at(:table)/:tr).collect{|x| x.children.collect{|x| x.it}}.flatten
    cells.should == 'Asset Accounts/Balance/Checking/$-1000.00/Liability Accounts/Balance/Credit Card/$1000.00'.split('/')
  end

  it "earning spending should be correct" do
    DB[:entries].insert(:date=>'2008-04-07'.to_date, :reference=>'1001', :entity_id=>2, :credit_account_id=>3, :debit_account_id=>4, :memo=>'Food', :amount=>100, :cleared=>false, :user_id=>1)
    cells = (page('/reports/earning_spending').at(:table)/:tr).collect{|x| x.children.collect{|x| x.it}}.flatten
    cells.should == 'Account/June 2008/May 2008/April 2008/March 2008/February 2008/January 2008/December 2007/November 2007/October 2007/September 2007/August 2007/July 2007/Food///$-100.00//////////Salary///$100.00////////// '.split('/')[0...-1]
  end

  it "income expense should be correct" do
    cells = (page('/reports/income_expense').at(:table)/:tr).collect{|x| x.children.collect{|x| x.it}}.flatten
    cells.should == 'Month|Income|Expense|Profit/Loss|2008-06|$0.00|$0.00|$0.00|2008-04|$100.00|$100.00|$0.00'.split('|')
  end

  it "net worth should be correct" do
    cells = (page('/reports/net_worth').at(:table)/:tr).collect{|x| x.children.collect{|x| x.it}}.flatten
    cells.should == 'Month/Assets/Liabilities/Net Worth/Current/$-1000.00/$-1000.00/$0.00/Start of 2008-06/$0.00/$0.00/$0.00/Start of 2008-04/$0.00/$0.00/$0.00'.split('/')
  end
end
