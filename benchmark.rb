
login = "-i ~/.ssh/fauna-default-keypair.pem ec2-user@ec2-23-20-42-109.compute-1.amazonaws.com"

servers = [
  # App folder and subdomain, URL
  ["scala-finagle", "/"],
  ["c-c", "/"],
  ["java-jetty", "/"],
  [ "js-node", "/"],
  ["ruby-sinatr", "/"],
  ["java-tomcat", "/servlet"],
  ["python-bottle", "/"]
]

dynos = 3
low = 20 * dynos
high = 120 * dynos
step = 5 * dynos
calls = 25
test_time = 30

puts servers.inspect

def run(command)
  puts "--> #{command}"
  system(command)
end

watcher = Thread.new do
  while(1)
    line = `ssh #{login} \"sudo ps auwx | grep h[t]tperf\"`
    line = line.split(" ")
    if line[9].to_i > 1 # 1 minute
      puts "Killing #{line[1]} (#{line[9]} minutes)"
      run "ssh #{login} sudo kill #{line[1]}"
    end
    sleep(5)
  end
end

servers.each do |prefix, uri|
 results = prefix + uri[1..-1] + ".csv"
 output = prefix + uri[1..-1] + ".out"
 command = "sudo env PATH=/usr/local/bin:$PATH autobench --single_host --host1 #{prefix}.herokuapp.com --uri1 #{uri} --low_rate #{low} --high_rate #{high} --rate_step #{step} --num_call #{calls} --const_test_time #{test_time} --timeout 30 --output_fmt csv --file #{results} 2>&1 | tee -a #{output}"

  puts "*** #{prefix} ***"
  File.unlink(output) if File.exist?(output)
  run("cd #{prefix} && heroku restart && heroku ps:scale web=#{dynos}")
  sleep(1)
  run("ssh #{login} #{command}")
  run("cd #{prefix} && heroku ps:scale web=1")
  run("scp #{login}:#{results} .")
end

Thread.kill(watcher)


