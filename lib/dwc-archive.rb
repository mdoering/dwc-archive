# encoding: UTF-8
$:.unshift(File.dirname(__FILE__)) unless
   $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))   
R19 = RUBY_VERSION.split('.')[0..1].join('').to_i > 18
require 'ruby_extensions'
require 'fileutils'
require 'ostruct'

if R19
  require 'csv'
else
  require 'fastercsv'
  CSV = FasterCSV
end
require 'dwc-archive/ingester'
require 'dwc-archive/errors'
require 'dwc-archive/expander'
require 'dwc-archive/archive'
require 'dwc-archive/core'
require 'dwc-archive/extension'
require 'dwc-archive/metadata'
require 'dwc-archive/generator'
require 'dwc-archive/generator_meta_xml'
require 'dwc-archive/generator_eml_xml'
require 'dwc-archive/classification_normalizer'

class DarwinCore
  
  VERSION = open(File.join(File.dirname(__FILE__), '..', 'VERSION')).readline.strip

  attr_reader :archive, :core, :metadata, :extensions
  alias :eml :metadata
  
  DEFAULT_TMP_DIR = "/tmp"
  
  def self.nil_field?(field)
    return true if [nil, '', '/N'].include?(field)
    false
  end
  
  def self.clean_all(tmp_dir = DEFAULT_TMP_DIR)
    Dir.entries(tmp_dir).each do |entry|
      path = File.join(tmp_dir, entry)
      if FileTest.directory?(path) && entry.match(/^dwc_[\d]+$/)
        FileUtils.rm_rf(path)
      end
    end
  end

  def initialize(dwc_path, tmp_dir = DEFAULT_TMP_DIR)
    @archive = DarwinCore::Archive.new(dwc_path, tmp_dir) 
    @core = DarwinCore::Core.new(@archive)
    @metadata = DarwinCore::Metadata.new(@archive)
    @extensions = get_extensions
  end

  # generates a hash from a classification data with path to each node, list of synonyms and vernacular names.
  def normalize_classification(verbose = false)
    return nil unless has_parent_id?
    DarwinCore::ClassificationNormalizer.new(self, verbose).normalize
  end

  def has_parent_id?
    !!@core.fields.join('|').downcase.match(/highertaxonid|parentnameusageid/)
  end

  private
  def get_extensions
    res = []
    root_key = @archive.meta.keys[0]
    ext = @archive.meta[root_key][:extension]
    return [] unless ext
    ext = [ext] if ext.class != Array
    ext.map { |e| DarwinCore::Extension.new(@archive, e) }
  end
end
