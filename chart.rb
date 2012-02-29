
require 'csv'

data = {}
range_responses = 16250
range_errors = 100
range_response_time = 10000
smoothness=0.2
dynos=3

Dir['*.csv'].each do |file|
  CSV.foreach(file) do |line|
    line[7] = range_response_time if !line[7]
    line.map! {|n| n || 0}
    data[line[0]] ||= []
    data[line[0]] += line[1..-1]
  end
end

data["dem_req_rate"].map! do |column|
  column.gsub(".herokuapp.com", "").gsub("-", "_")
end

File.open('tmp/chart.csv', 'w') do |file|
  data.map do |line|
    file.puts line.flatten.join(",")
  end
end

File.open('tmp/chart.r', 'w') do |file|
  file.puts <<-preamble
    range_responses = #{range_responses}
    range_response_time = #{range_response_time}
    range_errors = #{range_errors}
    smoothness = #{smoothness}
    data = read.table('tmp/chart.csv', header=T, sep=',')
    attach(data)
    quartz('Throughput', 8, 6)
    par(mar=c(5,5,5,5))
    xl <- seq(min(dem_req_rate),max(dem_req_rate), (max(dem_req_rate) - min(dem_req_rate))/1000)
    Sys.sleep(1)
  preamble

  labels = []
  data["dem_req_rate"].each do |l|
    if l =~ /avg_rep_rate_(.*?)_(.*?)$/
      language, server = $1, $2
      case server
        when "c"
          server = "accept"
        when "sinatr"
          server = "sinatra"
      end
      labels << "#{language.capitalize} (#{server.capitalize})"
    end
  end

  colors = %w(red blue black green purple pink cyan magenta orange)[0..labels.size]

  i = 0
  data["dem_req_rate"].each do |y|
    next unless y =~ /avg_rep_rate_/
    file.puts <<-plotter
      par(new=T)
      plot(dem_req_rate, #{y}, ylim=c(0,range_responses), axes=F, ann=F, type='n')
      smooth = smooth.spline(dem_req_rate, #{y}, spar=smoothness)
      lines(predict(smooth, dem_req_rate), col='#{colors[i]}', lwd=2, lty=1)
    plotter
    i = i + 1
  end

  i = 0
  data["dem_req_rate"].each do |y|
    next unless y =~ /errors_/
    file.puts <<-plotter
      par(new=T)
      plot(dem_req_rate, #{y}, ylim=c(0,range_errors), axes=F, ann=F, type='n')
      smooth = smooth.spline(dem_req_rate, #{y}, spar=smoothness)
      lines(predict(smooth, dem_req_rate), col='#{colors[i]}', lwd=2, lty=3)
    plotter
    i = i + 1
  end

  file.puts <<-postamble
    par(new=T)
    plot(dem_req_rate, dem_req_rate, ylim=c(0,range_responses), axes=F, ann=F, type='n')
    abline(0,1, lty=3, col='gray')
    title(main='Throughput of HTTP hello-world on Heroku with #{dynos} Dynos')
    axis(1)
    axis(2)
    legend(range_responses/6.5, range_responses, c(#{labels.inspect[1..-2]}), cex=0.8, col=c(#{colors.inspect[1..-2]}), pch=21:22)

    par(new=T)
    plot(dem_req_rate, dem_req_rate, ylim=c(0,range_errors), axes=F, ann=F, type='n')
    axis(4)

    title(xlab="Requests per second", ylab="Responses per second")
    title(ylab="% connection errors", line=-34)

    box()
  postamble

  file.puts <<-preamble
    quartz('Latency', 8, 6)
    par(mar=c(5,5,5,5))
  preamble

  i = 0
  data["dem_req_rate"].each do |y|
    next unless y =~ /resp_time_/
    file.puts <<-plotter
      par(new=T)
      plot(dem_req_rate, log10(#{y}), ylim=c(0,log10(range_response_time)), axes=F, ann=F, type='n')
      smooth = smooth.spline(dem_req_rate, log10(#{y}), spar=smoothness)
      lines(predict(smooth, dem_req_rate), col='#{colors[i]}', lwd=2, lty=1)
    plotter
    i = i + 1
  end

  file.puts <<-postamble
    par(new=T)
    title(main='Latency of HTTP hello-world on Heroku with #{dynos} Dynos')
    axis(1)
    axis(2, at=axTicks(2), c(0, 10, 100, 1000, 10000))
    legend(range_responses*0.76, log10(range_response_time)*0.35, c(#{labels.inspect[1..-2]}), cex=0.8, col=c(#{colors.inspect[1..-2]}), pch=21:22)
    title(xlab="Requests per second", ylab="Milliseconds (log scale)")

    box()
    Sys.sleep(30)
  postamble
end

exec("R --no-save < tmp/chart.r")

