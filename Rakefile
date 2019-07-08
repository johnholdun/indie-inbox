require 'rake'
require './environment'

namespace(:inbox) do |args|
  desc('Parse unverified incoming items')
  task('parse') do
    ParseInbox.call
  end
end

namespace(:outbox) do |args|
  desc('Parse outgoing items')
  task('parse') do
    ParseOutbox.call
  end
end
