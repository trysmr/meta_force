worker_processes Integer(ENV['WEB_CONCURRENCY'] || 2)
timeout 15
preload_app true
if ENV['RACK_ENV'] == 'development'
  listen 4567
else
  listen './tmp/sockets/unicorn.sock', backlog: 32
end
pid './tmp/pids/unicorn.pid'

stderr_path File.expand_path('./log/unicorn.log')
stdout_path File.expand_path('./log/unicorn.log')

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end
end
