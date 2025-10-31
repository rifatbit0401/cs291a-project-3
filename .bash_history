bundle install
cd help_desk_backend/
bundle install
rails db:create
rails server -b 0.0.0.0 -p 3000
clear
rails generate active_record:session_migration
rails db:migrate
rails server -b 0.0.0.0 -p 3000
rails server -b 0.0.0.0 -p 3000
rm -f tmp/pids/server.pid
rails server -b 0.0.0.0 -p 3000
exit
exit
