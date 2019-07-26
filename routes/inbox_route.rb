# All we're doing here is capturing this request to be parsed later by
# {ParseInboxItem}
class InboxRoute < Route
  def call
    DB[:unverified_inbox].insert \
      actor_id: request.params['actor_id'],
      body: request.body.tap(&:rewind).read.force_encoding('UTF-8'),
      headers: request['headers'].to_json,
      path: request.path,
      request_method: request.request_method.downcase,
      cursor: (Time.now.to_f * 1000).to_i

    202
  end
end
