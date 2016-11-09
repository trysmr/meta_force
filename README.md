# MetaForce

salesforce.com のオブジェクト一覧、オブジェクトの項目一覧を表示する簡易 Web アプリです。

## 使い方

```
$ git clone https://github.com/trysmr/meta_force.git
$ cd meta_force
$ bundle install --path=vendor/bundle
$ vi ./config.yml
$ bundle exec rackup -p 4567
```

./config.yml には salesforce.com の接続アプリケーションの情報を入力します。

### 例

```
development:
  client_id: 'YOUR_CLIENT_KEY'
  client_secret: 'YOUR_CLIENT_SECRET'
  scope: 'id api web'
```

### unicorn.rb

```
worker_processes Integer(ENV['WEB_CONCURRENCY'] || 2)
timeout 15
preload_app true
if ENV['RACK_ENV'] == 'development'
  listen 4567
else
  listen '/var/lib/meta_force/tmp/sockets/unicorn.sock', backlog: 32
end
pid '/var/lib/meta_force/tmp/pids/unicorn.pid'

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

```

## デモ画面

### オブジェクト一覧画面

![オブジェクト一覧画面](demo01_objects.png)

### オブジェクトの項目一覧画面

![オブジェクトの項目一覧画面](demo02_fields.png)

## TODO
* テストコード
* ビューでアクセスできないけど keyPrefix があるのでリンクが貼ってあるオブジェクトがいくつも...
