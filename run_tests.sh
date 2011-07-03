#!/bin/sh
WAITTIME=5
BUNDLE=bundle
UNICORN=unicorn
SPEC=spec
if [ X"$RUBY" == "Xruby19" ]; then
  BUNDLE=bundle19
  UNICORN=unicorn19
  SPEC=spec19
fi
echo -n '' > log/test.log
echo -n '' > /var/www/logs/unicorn/spam.test.log
$BUNDLE exec $UNICORN -c config/unicorn.test.conf -D
sleep $WAITTIME
$SPEC test.rb
kill `cat /var/www/tmp/spam.test.pid`
