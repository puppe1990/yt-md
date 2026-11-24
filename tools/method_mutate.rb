# frozen_string_literal: true

# &&/|| swap mutants for Ruby. Uncle Bob's mutator does not parse .rb;
# this lever kills operator survivors in lib/.
module MethodMutate
  Site = Struct.new(:path, :index, :from, :to, keyword_init: true)

  module_function

  def sites_in(source, path: nil)
    found = []
    source.scan(/&&|\|\|/) do
      token = Regexp.last_match[0]
      found << Site.new(
        path: path,
        index: Regexp.last_match.begin(0),
        from: token,
        to: token == "&&" ? "||" : "&&"
      )
    end
    found
  end

  def apply(source, index, from, to)
    got = source[index, from.length]
    raise "expected #{from.inspect} at #{index}, got #{got.inspect}" if got != from

    source.dup.tap { |copy| copy[index, from.length] = to }
  end

  def sites_in_lib(lib_glob)
    Dir.glob(lib_glob).flat_map { |path| sites_in(File.read(path), path: path) }
  end

  def run_sites(sites, test_command:, stdout:)
    killed = 0
    survivors = []
    sites.each_with_index do |site, offset|
      original = File.read(site.path)
      File.write(site.path, apply(original, site.index, site.from, site.to))
      begin
        ok = system(test_command, out: File::NULL, err: File::NULL)
        if ok
          survivors << site
          stdout.puts "SURVIVED #{offset + 1}/#{sites.size} #{site.path}:#{site.index} #{site.from}->#{site.to}"
        else
          killed += 1
          stdout.puts "killed    #{offset + 1}/#{sites.size} #{site.path}:#{site.index} #{site.from}->#{site.to}"
        end
      ensure
        File.write(site.path, original)
      end
    end
    stdout.puts "killed #{killed}/#{sites.size}, survivors #{survivors.size}"
    survivors.empty? ? 0 : 3
  end
end
