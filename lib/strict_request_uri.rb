require 'rack'

# Sometimes junk gets appended to the URLs clicked in e-mails.
# This junk then gets sent by browsers undecoded, and causes Unicode-related
# exceptions when the full request URI or path is rebuilt for ActionDispatch.
#
# We can fix this by iteratively removing bytes from the end of the URL until it becomes parseable.
#
# We do however answer to those URLs with a 400 to indicate clients that those requests are not
# welcome. This also allows us to tell the users that they are using a URL which is in fact
# not really valid.
class StrictRequestUri
  VERSION = '1.0.0'
  
  # Inits the middleware. The optional proc should be a Rack application that 
  # will render the error page. To make a controller render that page,
  # use <ControllerClass>.action()
  #
  #   use RequestUriCleanup do | env |
  #       ErrorsController.action(:invalid_request).call(env)
  #   end
  def initialize(app, &error_page_rack_app)
    @app = app
    @error_page_app = if error_page_rack_app
      error_page_rack_app
    else
      ->(env) { [400, {'Content-Type' => 'text/plain'}, ['Invalid request URI']] }
    end
  end
  
  def call(env)
    # Compose the original URL, taking care not to treat it as UTF8.
    # Do not use Rack::Request since it is not really needed for this
    # (and _might be doing something with strings that we do not necessarily want).
    # For instance, Rack::Request does regexes when you ask it for the REQUEST_URI
    tainted_url = reconstruct_original_url(env)
    return @app.call(env) if string_parses_to_url?(tainted_url)
    
    # At this point we know the URL is fishy.
    referer = to_utf8(env['HTTP_REFERER'] || '(unknown)')
    env['rack.errors'].puts("Invalid URL received from referer #{referer}") if env['rack.errors']
    
    # Save the original URL so that the error page can use it
    env['strict_uri.original_invalid_url'] = tainted_url
    env['strict_uri.proposed_fixed_url'] = 
      truncate_bytes_at_end_until_parseable(tainted_url)
    
    # Strictly speaking, the parts we are going to put into QUERY_STRING and PATH_INFO
    # should _only_ be used for rendering the error page, and that's it.
    # 
    # We can therefore wipe them clean.
    env['PATH_INFO'] = '/invalid-url'
    env['QUERY_STRING'] = ''
    
    # And render the error page using the provided error app.
    @error_page_app.call(env)
  end
  
  private
  
  # Reconstruct the original URL from the Rack env variables, converting them to
  # binary encoding before joining them together. This ensures the "bad" bits stay
  # broken and no errors are raised. 
  def reconstruct_original_url(env)
    original_url_components = env.values_at('SCRIPT_NAME', 'PATH_INFO')
    unless env['QUERY_STRING'].empty?
      original_url_components << '?'
      original_url_components << env['QUERY_STRING']
    end
    original_url_components.map{|e| e.unpack("C*").pack("C*") }.join
  end
  
  def string_parses_to_url?(string)
    # We can have two sorts of possible damage.
    # First sort is when raw garbage bytes just get added to the URL.
    # This can be caught by attempting to parse the URL with URI().
    parsed_uri = URI(string)
    # The second kind of damage is when there _is_ in fact a normal URL-encoded
    # character, which URI() will happily swallow - but this character is not valid
    # UTF-8 and will make the Rails router crash. For our purposes it _also_ means
    # the URL has been damaged bayound repair.
    decoded_uri = Rack::Utils.unescape(string).unpack("U*")
    true
  rescue URI::InvalidURIError, ArgumentError
    false
  end
  
  def to_utf8(str, repl_char='?')
    str.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: repl_char)
  end
  
  # Chops off one byte from the given string iteratively, until the string can be parsed
  # using URI() _and_ decoded using Rack::Utils.unescape.
  def truncate_bytes_at_end_until_parseable(str)
    cutoff = -1
    until str.empty? do
      str = str[0..cutoff]
      return str if string_parses_to_url?(str)
      cutoff -= 1
    end
    ''
  end
end
