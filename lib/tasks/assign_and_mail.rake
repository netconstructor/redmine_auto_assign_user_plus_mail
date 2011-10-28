require File.expand_path(File.dirname(__FILE__) + "/../../../../../config/environment")
require "mailer"
require 'soap/wsdlDriver'
require 'digest/md5'
require 'iconv'

class RB_Assigner < Mailer

  def  self.reminders_all(options={})


#    p options
   
    tracker = options[:tracker] ? Tracker.find(options[:tracker]) : nil 
    role = options[:role] ? Role.find(options[:role]) : 1
    status = options[:status] ? IssueStatus.find(options[:status]) :1
    login_sms= options[:login]

    password_sms=  options[:password] ? Digest::MD5.new << options[:password] : nil


    s = ARCondition.new ["#{Issue.table_name}.status_id = #{status.id}"] if status #jeśli status się zgadza
    s << "#{Issue.table_name}.assigned_to_id IS NULL"                          #jeśli czy nie jest dopisane
    s << "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}"                #jeśli projekt jest active
    s << "#{Issue.table_name}.tracker_id = #{tracker.id}" if tracker               #jeśli tracker się zgadza
  
    author_list=Array.new
    assignee_list=Array.new
    blank_issues= Issue.find(:all, :include => [:project],:conditions => s.conditions)
    blank_issues.each do |issue|
      found_author=0
      found_assignee=0
      author_list.each do  |author|

        if author[0].mail==issue.author.mail then
          if author[2].is_a?(Issue)then
            temp= author[2]
            author[2]=Array.new
            author[2]<<temp
          end
          author[2]<<issue
          found_author=1
        end
      end

      possible_assignees = issue.project.users_by_role
      unless possible_assignees[role].blank?
          issue.assigned_to_id = possible_assignees[role].shuffle!.first.id
      #   issue.save
        assignee_list.each do |assignee|
          
          if assignee[0].mail== issue.assigned_to.mail then
            if assignee[2].is_a?(Issue)then
              temp= assignee[2]
              assignee[2]=Array.new
              assignee[2]<<temp
            end
            assignee[2]<<issue
            found_assignee=1

          end
          
          
        end


        if found_assignee == 0 then
          assignee_list<<[issue.assigned_to, "assignee",issue]
        end

        if found_author == 0
          then

          author_list << [issue.author,"author", issue]


        end
      end

  
    end




    author_list+=assignee_list










    #przerobka

    author_list.sort! do
      |x,y| x[0].mail+x[1] <=> y[0].mail+y[1]
    end
    previous_user = author_list[0][0] unless author_list[0].nil?

    auth_tasks = Array.new
    assigned_tasks = Array.new
    sent_issues = Array.new



    author_list.each do |user, type, issues|



      if previous_user == user then
        




        if type == "assignee" then
          assigned_tasks += issues.to_a
          sent_issues += issues.to_a
        elsif type == "author" then
          auth_tasks += issues.to_a
          sent_issues += issues.to_a
        end

      else

  #      deliver_send_mail(previous_user, assigned_tasks, auth_tasks) unless previous_user.nil?
   #     deliver_send_sms(previous_user, assigned_tasks, auth_tasks) unless previous_user.nil?
   send_sms(previous_user, assigned_tasks,login_sms, password_sms) unless previous_user.nil?


        assigned_tasks.clear
        auth_tasks.clear
        sent_issues.clear
        
  
        if type == "assignee" then
          assigned_tasks += issues.to_a
          sent_issues += issues.to_a
        elsif type == "author" then
          auth_tasks += issues.to_a
          sent_issues += issues.to_a
        end


      end
      previous_user=user
    end
  #  deliver_send_mail(previous_user, assigned_tasks, auth_tasks) unless previous_user.nil?
   # deliver_send_sms(previous_user, assigned_tasks, auth_tasks) unless previous_user.nil?
    send_sms(previous_user, assigned_tasks,login_sms, password_sms) unless previous_user.nil?

    
  end

  def self.send_sms(user, assigned_issues,login_sms, password_sms)




if assigned_issues.length > 0
case assigned_issues.length
  when 1 then message="In4mates, masz #{assigned_issues.size} nowe zadanie:"
 when 2..4 then message="In4mates, masz #{assigned_issues.size} nowe zadania:"
else message="In4mates, masz #{assigned_issues.size} nowych zadań:"
end

assigned_issues.each do |issue| 
  message << " * #{issue.project} - #{issue.tracker} ##{issue.id}: #{issue.subject}"
end

       phone = "48" + user.custom_field_values.first.value

      if phone

wsdl = 'https://ssl.smsapi.pl/webservices/v2/?wsdl'
driver = SOAP::WSDLDriverFactory.new(wsdl).create_rpc_driver

driver.wiredump_dev = STDOUT

    response =  driver.get_points({:username =>login_sms, :password => password_sms.to_s})


 if response.points.to_i >1 then

    response =  driver.send_sms({:client => {:username => login_sms,:password => password_sms.to_s }, :sms => {:recipient => phone, :eco=> 1, :sender => "SMSAPI", :message => message.to_ascii+"[%1%]",  :date_send => 0, :idx => nil,
            :single_message => nil,
            :no_unicode => 1,
            :datacoding => nil,
            :partner_id => nil,
            :test => 1,
            :priority => nil,
            :udh => nil,
            :flash => nil,
            :details => nil
} })


    p response
      end #jesli jest kasa

        end #jesli jest numer

 end #jesli jest co wyslac
    
  end


   def send_mail(user, assigned_issues, auth_issues)
    set_language_if_valid user.language
    recipients user.mail
    #day_tag=[l(:mail_reminder_all_day1),l(:mail_reminder_all_day2),l(:mail_reminder_all_day2),l(:mail_reminder_all_day2),l(:mail_reminder_all_day5)]
    case (assigned_issues+auth_issues).uniq.size
	when 1 then subject l(:mail_subject_reminder_all1, :count => ((assigned_issues+auth_issues).uniq.size))
	when 2..4 then subject l(:mail_subject_reminder_all2, :count => ((assigned_issues+auth_issues).uniq.size))
	else subject l(:mail_subject_reminder_all5, :count => ((assigned_issues+auth_issues).uniq.size))
    end
    body :assigned_issues => assigned_issues,
	 :auth_issues => auth_issues
         
    #     :issues_url => url_for(:controller => 'issues', :action => 'index', :set_filter => 1, :assigned_to_id => user.id, :sort_key => 'due_date', :sort_order => 'asc')
    render_multipart('rb_assigner', body) if (assigned_issues+auth_issues).uniq.size>0
  end




end


namespace :redmine do
  task :assign_and_mail => :environment do
    options = {}
    options[:role]    = ENV['role']
    options[:tracker] = ENV['tracker']
    options[:status]  = ENV['status']
    options[:login]    = ENV['login']
    options[:password] =ENV['password']

    RB_Assigner.reminders_all(options)
  end
end


  
