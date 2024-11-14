require "stringex"
class Jekyll < Thor
  desc "new", "create a new post"
  method_option :editor, :default => "subl"
  def new(*title)
    title = title.join(" ")
    date = Time.now.strftime('%Y-%m-%d')
    filename = "_posts/#{date}-#{title.to_url}.markdown"

    if File.exist?(filename)
      abort("#{filename} already exists!")
    end

    puts "Creating new post: #{filename}"
    open(filename, 'w') do |post|
      post.puts "---"
      post.puts "layout: post"
      post.puts "title: \"#{title.gsub(/&/,'&amp;')}\""
      post.puts "subtitle: a nice subtitle you need to change"
      post.puts "tags: [testing]"
      post.puts "mermaid: true"
      post.puts 'credit-img: Photo by xxx'
      post.puts 'cover-img: assets/img/house_model_code.png'
      post.puts 'thumbnail-img: assets/img/house_model_code_tn.png'
      post.puts " -"
      post.puts "---"
    end

    system(options[:editor], filename)
  end
end
