desc 'cucumber [FILES and OPTIONS]', 'Run Cucumber features'
long_desc <<-LONGDESC
Example: `geordi cucumber features/authentication_feature:3`

Runs Cucumber as you want: with `bundle exec`, using parallel tests, with
a VNC session holding Selenium test browsers, support for using a dedicated
testing firefox and beta support for rerunning failed scenarios.

- *@solo:* Generally, features are run in parallel. However, scenarios tagged
with @solo are excluded and will be run sequentially, _after_ the parallel run.

- *Debugging:* Sometimes, the dot-printing Cucumber formatter does not show
errors. In case a feature fails without a message, try running it with `--debug`
or `-d`.

- *Options:* Any unknown option will be passed through to Cucumber,
e.g. `--format pretty`.
LONGDESC

option :modified, :aliases => '-m', :type => :boolean,
  :desc => 'Run all modified features'
option :containing, :aliases => '-c', :banner => 'STRING',
  :desc => 'Run all features that contain STRING'
option :verbose, :aliases => '-v', :type => :boolean,
  :desc => 'Print the testrun command'
option :debug, :aliases => '-d', :type => :boolean,
  :desc => 'Run with `-f pretty -b` which helps hunting down bugs'
option :rerun, :aliases => '-r', :type => :numeric, :default => 0,
  :desc => 'Rerun features up to N times while failing'

def cucumber(*args)
  if args.empty?
    # This is not testable as there is no way to stub `git` :(
    if options.modified?
      modified_features = `git status --short`.split($/).map do |line|
        indicators = line.slice!(0..2) # Remove leading indicators
        line if line.include?('.feature') and not indicators.include?('D')
      end.compact
      args = modified_features
    end

    if options.containing
      matching_features = `grep -lri '#{options.containing}' --include=*.feature features/`.split($/)
      args = matching_features.uniq
    end
  end

  if File.directory?('features')
    require 'geordi/cucumber'

    invoke_cmd 'bundle_install'

    cmd_opts, files = args.partition { |f| f.start_with? '-' }
    cmd_opts << '--format' << 'pretty' << '--backtrace' if options.debug

    announce 'Running features'

    # Normal run
    unless Geordi::Cucumber.new.run(files, cmd_opts, :verbose => options.verbose)
      cmd_opts << '--profile' << 'rerun'

      # Reruns
      (1 + options.rerun).times do |i|
        fail 'Features failed.' if (i == options.rerun) # All reruns done?

        announce "Rerun ##{ i + 1 } of #{ options.rerun }"
        break if Geordi::Cucumber.new.run(files, cmd_opts, :verbose => options.verbose, :parallel => false)
      end
    end

    # Serial run of @solo scenarios
    if files.any? { |f| f.include? ':' }
      note '@solo run skipped when called with line numbers' if options.verbose
    else
      files << 'features' if files.empty? # Proper grepping
      solo_tag_usages = `grep -r '@solo' #{ files.join(' ') }`.split("\n")

      if solo_tag_usages.any?
        cmd_opts << '--tags' << '@solo'

        announce 'Running @solo features'
        Geordi::Cucumber.new.run files, cmd_opts, :verbose => options.verbose, :parallel => false
      end

    end
  else
    note 'Cucumber not employed.'
  end
end
