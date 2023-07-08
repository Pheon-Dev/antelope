local module = {}

module.auto_handles =
  vim.split('hjklfdsagbvncmuioewrpqtyxzABCDEFGHIJKLMNOPQRSTUVWXYZ!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~', '')
  -- vim.split('asdfhjklgbvncmuioewrpqtyxzABCDEFGHIJKLMNOPQRSTUVWXYZ!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~', '')

return module
