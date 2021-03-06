
require 'csv'

data = {}
range_responses = 16250
range_errors = 100
range_response_time = 10000
smoothness=0.6

folder = ARGV[0]
folder = folder.chomp("/")
dynos = folder[/(\d+)/, 1].to_i

title = "HTTP hello-world on Heroku with #{dynos} Dyno#{'s' if dynos > 1}"

Dir["#{folder}/*.csv"].each do |file|
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

  file.puts <<-preamble
    data = read.table('tmp/chart.csv', header=T, sep=',')
    attach(data)
    dynos = #{dynos}
    dem_req_rate = dem_req_rate/dynos

    range_response_time = #{range_response_time}
    range_errors = #{range_errors}
    range_responses = max(dem_req_rate)
    smoothness = #{smoothness}

    legend_colors = c(#{colors.inspect[1..-2]})
    legend_labels = c(#{labels.inspect[1..-2]})

    png('#{folder}-throughput.png', width=8, height=6, units = 'in', res=150)
    par(mar=c(5,5,5,5))
    xl <- seq(min(dem_req_rate),max(dem_req_rate), (max(dem_req_rate) - min(dem_req_rate))/1000)
  preamble

  i = 0
  data["dem_req_rate"].each do |y|
    next unless y =~ /avg_rep_rate_/
    file.puts <<-plotter
      #{y} = #{y}/dynos
      par(new=T)
      plot(dem_req_rate, #{y}, ylim=c(0,range_responses), axes=F, ann=F, type='n')
      smooth = smooth.spline(dem_req_rate, #{y}, spar=smoothness)
      lines(predict(smooth, dem_req_rate), col='#{colors[i]}', lwd=3, lty=1)
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
    title(main='Throughput of #{title}')
    axis(1)
    axis(2)
    legend(range_responses * 0.1, range_responses * 0.95, legend_labels, cex=0.8, col=legend_colors, bg='white', fill=legend_colors, border=legend_colors)

    par(new=T)
    plot(dem_req_rate, dem_req_rate, ylim=c(0,range_errors), axes=F, ann=F, type='n')
    axis(4)

    title(xlab="Requests per second per dyno", ylab="Responses per second per dyno (solid line)")
    title(ylab="% connection errors (dashed line)", line=-34)

    box()
  postamble

  file.puts <<-preamble
    png('#{folder}-latency.png', width=8, height=6, units = 'in', res=150)
    par(mar=c(5,5,5,5))
  preamble

  i = 0
  data["dem_req_rate"].each do |y|
    next unless y =~ /resp_time_/
    file.puts <<-plotter
      par(new=T)
      plot(dem_req_rate, log10(#{y}), ylim=c(0,log10(range_response_time)), axes=F, ann=F, type='n')
      smooth = smooth.spline(dem_req_rate, log10(#{y}), spar=smoothness)
      lines(predict(smooth, dem_req_rate), col='#{colors[i]}', lwd=3, lty=1)
    plotter
    i = i + 1
  end

  file.puts <<-postamble
    par(new=T)
    title(main='Latency of #{title}')
    axis(1)
    axis(2, at=axTicks(2), c(0, 10, 100, 1000, 10000))
    legend(range_responses*0.8, log10(range_response_time)*0.4, legend_labels, cex=0.8, col=legend_colors, bg='white', fill=legend_colors, border=legend_colors)
    title(xlab="Requests per second per dyno", ylab="Milliseconds (log scale)")

    box()
  postamble
end

exec("R --no-save < tmp/chart.r")

