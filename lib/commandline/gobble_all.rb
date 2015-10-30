require 'fileutils'

class GobbleAll
  include GobbleShare
  
  def initialize( rails_root, type, ext, options )
    @rails_root = rails_root
    @options = options
    @text_extractor_type = type
    @extension = ext
  end

  def execute
    puts "Processing all of: #{@rails_root}"
    puts ""

    if( @text_extractor_type == 'tr8n' )
      execute_tr8n
    else
      execute_i18n      
    end
    
  end
  
  def valid?
    @options.empty?
  end


  private

  def execute_tr8n
    rails_view_directory = "#{@rails_root}/app/views"
    text_extractor = Tr8nTextExtractor.new
    
    Dir["#{rails_view_directory}/**/*#{@extension}" ].each do |full_erb_file_path|

      erb_file = full_erb_file_path.gsub( @rails_root, '' )
      erb_file = ErbFile.load( full_erb_file_path )
      erb_file.extract_text( text_extractor )

      File.open(full_erb_file_path, 'w') {|f| f.write(erb_file.to_s) }
      puts "Wrote #{full_erb_file_path}"
    end

  end
  
  def execute_i18n
    rails_view_directory = "#{@rails_root}/app/views"

    Dir["#{rails_view_directory}/**/*" ].each do |full_erb_file_path|
      unless should_process?(full_erb_file_path)
        next
      end

      yml_relative_path = full_erb_file_path.gsub("#{@rails_root}/app/", '')
      en_yml_relative_path = yml_relative_path.gsub('html.erb', 'en.yml').gsub('text.erb', 'en.yml')

      full_yml_file_path = "#{@rails_root}/config/locales/#{en_yml_relative_path}"
      rails_translation_store = RailsTranslationStore.load_from_file( full_yml_file_path )
      text_extractor = RailsTextExtractor.new( rails_translation_store )

      erb_file = full_erb_file_path[@rails_root.length,full_erb_file_path.length]
      rails_translation_store.start_new_context( convert_path_to_key_path( erb_file.to_s ) )
      erb_file = ErbFile.load( full_erb_file_path )
      erb_file.extract_text( text_extractor )

      write_files_if_needed(erb_file, full_erb_file_path, full_yml_file_path, rails_translation_store)
    end
  end

  def should_process?(file)
    process = false
    keywords = %w(
      /views/buying/_gateway_outage.
      /views/buying/confirmation/_page.
      /views/buying/email/_order_confirmation.
      /views/buying/email/order_confirmation/_order_entry_summary.
      /views/cart/_configure_before_adding_modal.
      /views/cart/_entry.
      /views/cart/_footer.
      /views/cart/_header.
      /views/cart/_sidebar.
      /views/item/_edit_basic_details.
      /views/item/_grid.
      /views/item/_license_pricing.
      /views/item/index.
      /views/item/sidebar/_copyright.
      /views/item/sidebar/_pricebox.
    )
    keywords.each do |keyword|
      if file.include? keyword
        process = true
        break
      end
    end
    process
  end

  def write_files_if_needed(erb_file, full_erb_file_path, full_yml_file_path, rails_translation_store)
    yml_contents = rails_translation_store.serialize
    if some_content? yml_contents
      yml_file_dir = File.dirname(full_yml_file_path)
      FileUtils.mkdir_p(yml_file_dir) unless File.exists?(yml_file_dir)

      File.open(full_yml_file_path, 'w') { |f| f.write(yml_contents) }
      puts "Wrote #{full_yml_file_path}"

      File.open(full_erb_file_path, 'w') { |f| f.write(erb_file.to_s) }
      puts "Wrote #{full_erb_file_path}"
    end
  end

  def some_content?(content)
    "#{content} ".strip.chomp != 'en:'
  end

end
