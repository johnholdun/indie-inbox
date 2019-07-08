class Schema
  def self.load!
    DB.run('create extension if not exists "uuid-ossp"')

    DB.create_table?(:actors) do
      primary_key :id, :uuid, default: Sequel.lit('uuid_generate_v4()')
      column :uri, :text, unique: true, null: false
      column :managed, :boolean, null: false, default: false
      column :private_key, :text
      column :auth_token, :uuid
      column :fetched_at, :timestamptz, null: false
      column :json, :json, null: false
      check { Sequel.lit('managed = false or (private_key is not null and auth_token is not null)') }
    end

    DB.create_table?(:activities) do
      primary_key :id, :uuid, default: Sequel.lit('uuid_generate_v4()')
      column :uri, :text
      foreign_key :actor_id, :actors, type: :uuid, null: false
      column :delivered, :boolean, null: false, default: false
      column :json, :json, null: false
    end

    DB.create_table?(:inbox) do
      primary_key :id, :uuid, default: Sequel.lit('uuid_generate_v4()')
      foreign_key :actor_id, :actors, type: :uuid, null: false
      foreign_key :activity_id, :activities, type: :uuid, null: false
    end

    DB.create_table?(:follows) do
      foreign_key :actor_id, :actors, type: :uuid, null: false
      foreign_key :object_id, :actors, type: :uuid, null: false
      column :accepted, :boolean, null: false, default: false
    end

    DB.create_table?(:unverified_inbox) do
      primary_key :id, :uuid, default: Sequel.lit('uuid_generate_v4()')
      column :body, :text
      column :headers, :json
      column :path, :text
      column :request_method, :text
      foreign_key :actor_id, :actors, type: :uuid
      column :errors, :json
    end
  end
end
