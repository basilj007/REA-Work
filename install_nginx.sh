#! /bin/bash
sudo yum update -y
sudo yum remove ruby* httpd -y
sudo yum install ruby24 git nginx vim -y
sudo chkconfig nginx on
sudo gem install bundler
cd /mnt
sudo git clone https://github.com/rea-cruitment/simple-sinatra-app.git
sudo chown ec2-user: simple-sinatra-app
sudo sed -i 's/localhost/localhost:9292/g' /etc/nginx/nginx.conf
sudo sed -i 's|/usr/share/nginx/html|/mnt/simple-sinatra-app|g'  /etc/nginx/nginx.conf
sudo ex -s -c '50i|proxy_pass http://localhost:9292;' -c x /etc/nginx/nginx.conf
sudo /etc/init.d/nginx start
cd /mnt/simple-sinatra-app
sudo /usr/local/bin/bundle install
sudo sed -i '/json/d' /usr/local/share/ruby/gems/2.4/gems/rack-2.2.2/lib/rack/session/cookie.rb
sudo nohup /usr/local/bin/bundle exec /usr/local/bin/rackup &
sudo /etc/init.d/nginx restart
