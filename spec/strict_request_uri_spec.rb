require_relative 'spec_helper'

describe StrictRequestUri do
  context 'with a good URL' do
    it 'returns the downstream response for URLs without a query string' do
      env_with_valid_chars = {
        'SCRIPT_NAME' => 'myscript',
        'PATH_INFO' => '/items/457',
        'QUERY_STRING' => ''
      }
      app = ->(env) {
        expect(env['QUERY_STRING']).to eq('')
        expect(env['SCRIPT_NAME']).to eq('myscript')
        expect(env['PATH_INFO']).to eq('/items/457')
        :total_success
      }
      expect(described_class.new(app).call(env_with_valid_chars)).to eq(:total_success)
    end
  
    it 'returns the downstream response for URLs with a query string' do
      env_with_valid_chars = {
        'SCRIPT_NAME' => 'myscript',
        'PATH_INFO' => '/items/457',
        'QUERY_STRING' => 'foo=bar'
      }
      app = ->(env) {
        expect(env['QUERY_STRING']).to eq('foo=bar')
        expect(env['SCRIPT_NAME']).to eq('myscript')
        expect(env['PATH_INFO']).to eq('/items/457')
        :total_success
      }
      expect(described_class.new(app).call(env_with_valid_chars)).to eq(:total_success)
    end
  end
  
  context 'with a garbage URL' do
    it 'calls the default error app if none was set' do
      # All of those 3 components are required as per Rack spec
      env_with_invalid_chars = {
        'SCRIPT_NAME' => '',
        'PATH_INFO' => [107, 17, 52, 140].pack("C*"),
        'QUERY_STRING' => '',
      }
    
      middleware = described_class.new(nil) # will raise if the wrapped app is called
      status, headers, body = middleware.call(env_with_invalid_chars)
      expect(status).to eq(400)
      expect(headers).to eq({'Content-Type' => 'text/plain'})
      expect(body).to eq(['Invalid request URI'])
    end
  
    it 'with junk after the path calls the error app instead' do
      # The related bug ticket - https://www.assembla.com/spaces/wetransfer-2-0/tickets/1568
      script_name = 'myscript'
      valid_part = '/items/457'
      invalid_part = [107, 17, 52, 140].pack("C*")
      invalid_path_info = valid_part.encode(Encoding::BINARY) + invalid_part
    
      expect {
        invalid_path_info.encode(Encoding::UTF_8)
      }.to raise_error(Encoding::UndefinedConversionError)
    
      # All of those 3 components are required as per Rack spec
      env_with_invalid_chars = {
        'SCRIPT_NAME' => script_name,
        'PATH_INFO' => invalid_path_info,
        'QUERY_STRING' => '',
        'rack.errors' => double('IO')
      }
    
      # Do not render from the controller since we do not have a complete Rack env hash initialized.
      # Instead, sneak in our own testing Proc.
      error_handling_app = ->(env) {
        # Make sure those are now safe to concat with each other
        expect(env['SCRIPT_NAME']).to eq("myscript")
        expect(env['PATH_INFO']).to eq("/invalid-url")
        expect(env['QUERY_STRING']).to eq('')
      
        # Make sure the original broken URL is stashed somewhere for the error page to act on
        expect(env['strict_uri.original_invalid_url']).to include(script_name)
        expect(env['strict_uri.original_invalid_url']).to include(invalid_path_info)
        expect(env['strict_uri.proposed_fixed_url']).to eq("myscript/items/457k")
      
        # Ensure those are valid - if this call raises the spec will fail
        env['PATH_INFO'].encode(Encoding::UTF_8)
      
        [200, {'Content-Type' => 'text/plain'}, ['This is an error message']]
      }
      
      expect(env_with_invalid_chars['rack.errors']).to receive(:puts).
        with("Invalid URL received from referer (unknown)")
    
      middleware = described_class.new(nil, &error_handling_app) # will raise if the wrapped app is called
      status, headers, body = middleware.call(env_with_invalid_chars)
      expect(status).to eq(200)
      expect(headers).to eq({'Content-Type' => 'text/plain'})
    end

    it 'after the query string calls the error app instead' do
      # The related bug ticket - https://www.assembla.com/spaces/wetransfer-2-0/tickets/1568
      script_name = 'myscript'
      valid_path_info = '/items/457'
      query_string = 'foo=bar&baz=bad'
      invalid_part = [107, 17, 52, 140].pack("C*")
      invalid_qs = query_string.encode(Encoding::BINARY) + invalid_part
    
      expect {
        invalid_qs.encode(Encoding::UTF_8)
      }.to raise_error(Encoding::UndefinedConversionError)
    
      # All of those 3 components are required as per Rack spec
      env_with_invalid_chars = {
        'SCRIPT_NAME' => script_name,
        'PATH_INFO' => valid_path_info,
        'QUERY_STRING' => invalid_qs,
        'HTTP_REFERER' => 'https://megacorp.co/webmail.asp',
        'rack.errors' => double('IO')
      }
    
      error_handling_app = ->(env) {
        # Make sure those are now safe to concat with each other
        expect(env['SCRIPT_NAME']).to eq("myscript")
        expect(env['PATH_INFO']).to eq("/invalid-url")
        expect(env['QUERY_STRING']).to eq('')
      
        expect(env['strict_uri.original_invalid_url']).to include(valid_path_info)
        expect(env['strict_uri.original_invalid_url']).to include(invalid_qs)
      
        # Ensure those are valid - if this call raises the spec will fail
        env['QUERY_STRING'].encode(Encoding::UTF_8)
      
        [200, {'Content-Type' => 'text/plain'}, ['This is an error message']]
      }
      expect(env_with_invalid_chars['rack.errors']).to receive(:puts).
        with('Invalid URL received from referer https://megacorp.co/webmail.asp')
      
      # nil  will raise if the wrapped app is called
      middleware = described_class.new(nil, &error_handling_app)
      status, headers, body = middleware.call(env_with_invalid_chars)
      expect(status).to eq(200)
      expect(headers).to eq({'Content-Type' => 'text/plain'})
    end
  end

  context 'with production examples of garbled PATH_INFO' do
    it 'triggers with URL-encoded bytes that are invalid UTF-8 when decoded' do
      # Example from production - here at the end of the url you have
      # \xC2 in percent-encoded form, which cannot be converted to UTF-8.
      # If we let it through, it _can_ be rendered using request.original_url
      # but _cannot_ be used by Journey when url_for is called.
      #
      # So we have to intercept this as well. 
      path = '/downloads/918ab1e20586c0b4e1875b3789b84ec720150615173920' +
        '/a480d026f46b0f0533cec47545cd5e2820150615173920/0130a0%C2'
      fake_action = ->(env) {
        # Make sure those are now safe to concat with each other
        expect(env['SCRIPT_NAME']).to eq('')
        expect(env['PATH_INFO']).to eq('/invalid-url')
        expect(env['QUERY_STRING']).to eq('')
        
        expect(env['strict_uri.original_invalid_url']).not_to be_nil
        expect(env['strict_uri.proposed_fixed_url']).to match(/\/0130a0$/)
        expect(env['strict_uri.proposed_fixed_url']).to match(/^\/downloads\//)
        [200, :h, :b]
      }
      invalid_env = {
        'SCRIPT_NAME' => '',
        'PATH_INFO' => path,
        'QUERY_STRING' => '',
      }
      # nil will raise if the wrapped app is called
      middleware = described_class.new(nil, &fake_action)
      status, headers, body = middleware.call(invalid_env)
      expect(status).to eq(200)
      expect(headers).to eq(:h)
    end
    
    it 'triggers with raw bytes that cannot be URL-decoded' do
      # Example from production - just random gunk appended to the end of the URL
      path = '/downloads/918ab1e20586c0b4e1875b3789b84ec720150615173920' +
        '/a480d026f46b0f0533cec47545cd5e2820150615173920/0130a' + '���'
      
      fake_action = ->(env) {
        # Make sure those are now safe to concat with each other
        expect(env['SCRIPT_NAME']).to eq('')
        expect(env['PATH_INFO']).to eq('/invalid-url')
        expect(env['QUERY_STRING']).to eq('')
        
        expect(env['request_uri_cleanup.original_invalid_url']).not_to be_nil
        expect(env['request_uri_cleanup.proposed_fixed_url']).to match(/^\/downloads\//)
        expect(env['request_uri_cleanup.proposed_fixed_url']).to match(/0130$/)
        
        [200, :h, :b]
      }
      invalid_env = {
        'SCRIPT_NAME' => '',
        'PATH_INFO' => path,
        'QUERY_STRING' => '',
      }
      middleware = described_class.new(nil)
      status, headers, body = middleware.call(invalid_env)
      expect(status).to eq(400)
    end
  end
end
