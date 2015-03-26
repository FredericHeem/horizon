# 
# Friendbot is your friendly neighborhood stellar faucet.  It will
# sign and send transactions at the request of anyone, when given a secret seed.
# 
# NOTE: This functionality should not remain in within horizon.  We're including
# it here because the it's a simpler implementation. 
# 
class Friendbot
  include Celluloid

  def initialize(seed)
    @keypair = Stellar::KeyPair.from_seed seed
    refresh_sequence_number
  end

  def pay(address)
    destination = Stellar::KeyPair.from_address address

    tx = Stellar::Transaction.payment({
      account:     @keypair,
      destination: destination,
      sequence:    @sequence,
      amount:      [:native, 100_000000]
    })

    hex = tx.to_envelope(@keypair).to_xdr(:hex)
    ptx = PendingTransaction.create!(tx_envelope: hex)
    ptx.submit
    @sequence += 1
    # return submission 
  end

  private
  def refresh_sequence_number
    Hayashi::Account.connection_pool.with_connection do 
      account = Hayashi::Account.where(accountid: @keypair.address).first

      raise "invalid friendbot seed: account not found" if account.blank?

      @sequence = account.sequence
    end
  end
end