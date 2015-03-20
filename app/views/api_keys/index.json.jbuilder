json.array!(@api_keys) do |api_key|
  json.extract! api_key, :id
  json.extract! api_key, :uuid
end
