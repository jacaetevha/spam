require "rake"

task :default do
  begin
    sh "#{RUBY} -S unicorn -c config/unicorn.test.conf -D"
    sh "echo -n '' > log/test.log"
    sh "echo -n '' > /var/www/logs/unicorn/spam.test.log"
    sh "#{RUBY} -S spec unit_test.rb"
    sh "#{RUBY} -S spec test.rb"
  ensure
    sh "kill `cat /var/www/tmp/spam.test.pid`"
  end
end
