# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include Orders
  
  def button_for_url(text, url, options)
    raise "No Text Provided" unless text
    raise "No URL provided" unless url
    logger.debug options.inspect
    button_class  = options[:class]
    button_id     = options[:id]
    html  = "<span"
    html += " id='#{button_id}'" if button_id
    html += " class='#{button_class}'" if button_class
    html += "><a href='#{url}'>#{text}</a></span>"
    return html
  end
  
  def login_or_forgot_password
    return "<div class='submit_form'><input name='commit' type='submit' value=' Login ' /> <span class='secondary_action'>| <a href='/admin/users/forgot'>I forgot my password</a></span></div>"
  end
  
  def containerize(title, actions, &block)
    html  = <<-HTML
      <div class="container">
        <div class="actions">
    HTML
    actions.each do |action|
      html += "<a href='#{action.url}'>#{action.name}</a>"
    end
    html += <<-HTML
        </div>
        <div class="header">
          <div class="name">#{title}</div>
        </div>
        <div class="content">
          #{capture(&block)}
        </div>
      </div>
    HTML
    return html
  end
  
  # -- Admin Helpers --
    def titled_container(title, &block)
      html = <<-HTML
        <div class="titled_container">
          <h2 class="title">#{title}</h2>
          <div class="content">
            #{capture(&block)}
          </div>
        </div>
      HTML
      logger
      return html
    end
  # --
  
  def truncate_by_words(text, *args)
   options = args.extract_options!
   options[:length] = args[0] || 30
   options[:omission] = args[1] || "..."
   text.split[0..(options[:length]-1)].join(" ") +(text.split.size > options[:length] ? options[:omission] : "")
  end
end
