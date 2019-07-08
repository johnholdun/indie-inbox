require './lib/service'

class FollowAccepter < Service
  attribute :actor_uri
  attribute :activity

  def call
    account = FetchAccount.call(actor_uri)
    follower = FetchAccount.call(activity['actor'])

    Deliverer.call \
      account,
      follower['inbox'],
      id: nil,
      type: 'Accept',
      actor: account['id'],
      object: activity
  end
end
