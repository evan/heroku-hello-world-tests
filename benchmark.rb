
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

dynos = ARGV[0].to_i
raise if dynos < 1

# 1 4 7 10

low = 20 * dynos
high = 240 * dynos
step = 10 * dynos
calls = 25
test_time = 30

puts "Dynos: #{dynos}"
puts servers.inspect

dir = "results_#{dynos}"

unless File.exist?(dir)
  Dir.mkdir(dir)
end

def run(command)
  puts "--> #{command}"
  system(command)
end

watcher = Thread.new do
  while(1)
    line = `ssh #{login} \"sudo ps auwx | grep h[t]tperf\"`
    line = line.split(" ")
    if line[9].to_i >= 1
      puts "Killing #{line[1]} (#{line[9]} minutes)"
      run "ssh #{login} sudo kill #{line[1]}"
    end
    sleep(5)
  end
end

Dir.chdir(dir) do
  servers.each do |prefix, uri|
    results = prefix + uri[1..-1] + ".csv"
    output = prefix + uri[1..-1] + ".out"

    autobench = "sudo env PATH=/usr/local/bin:$PATH autobench --single_host --host1 #{prefix}.herokuapp.com --uri1 #{uri} --low_rate #{low} --high_rate #{high} --rate_step #{step} --num_call #{calls} --const_test_time #{test_time} --timeout 30 --output_fmt csv --file #{results} 2>&1 | tee -a #{output}"

    File.unlink(results) if File.exist?(results)
    File.unlink(output) if File.exist?(output)

    puts "*** #{prefix} ***"
    run("cd ../#{prefix} && heroku restart && heroku ps:scale web=#{dynos}")
    sleep(1)
    run("ssh #{login} #{autobench}")
    run("cd ../#{prefix} && heroku ps:scale web=1")
    run("scp #{login}:#{results} .")
  end
end

Thread.kill(watcher)


