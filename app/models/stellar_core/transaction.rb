class StellarCore::Transaction < StellarCore::Base
  self.table_name  = "txhistory"
  self.primary_key = "txid"

  belongs_to :ledger_header, {
    class_name: "StellarCore::LedgerHeader",
    foreign_key: :ledgerseq,
    primary_key: :ledgerseq,
  }

  delegate :tx,          to: :envelope
  delegate :result,      to: :result_pair
  delegate :min_ledger,  to: :tx
  delegate :max_ledger,  to: :tx
  delegate :operations,  to: :tx

  def success?
    result.result.code == Stellar::TransactionResultCode.tx_success
  end

  def envelope
    raw_envelope = Stellar::Convert.from_base64(self.txbody)
    Stellar::TransactionEnvelope.from_xdr(raw_envelope)
  end
  memoize :envelope

  def result_pair
    raw_result = Stellar::Convert.from_base64(self.txresult)
    Stellar::TransactionResultPair.from_xdr(raw_result)
  end
  memoize :result_pair

  def meta
    raw_meta = Stellar::Convert.from_base64(self.txmeta)
    Stellar::TransactionMeta.from_xdr(raw_meta).v0!
  end
  memoize :meta

  def submitting_account
    self.envelope.tx.source_account
  end
  alias source_account submitting_account

  def submitting_address
    Stellar::Convert.pk_to_address(submitting_account)
  end

  def submitting_sequence
    tx.seq_num
  end

  def fee_paid
    result.fee_charged
  end

  def result_code
    result.result.switch
  end

  def result_code_s
    result_code.name
  end

  def participants
    # get all entries with type of "account"
    all_changes = meta.changes + meta.operations.flat_map(&:changes)
    account_entries = all_changes.
      select{|e| e.value.type == Stellar::LedgerEntryType.account }

    # extract the account id from each (both live and dead
    # entries expose it through `account_id`)
    account_entries
      .map{|e| e.value.account!.account_id}
      .uniq
  end
  memoize :participants


  def participant_addresses
    participants.map{|a| Stellar::Convert.pk_to_address(a)}
  end
  memoize :participant_addresses

  def operations_of_type(type)
    operations.select{|op| op.body.type == type }
  end

  def operation_results
    # TransactionResult => TransactionResult::Result => Array<OperationResult>
    result.result.results!
  end

  def operation_count
    operations.length
  end

  memoize def operations_with_results
    operations.zip(operation_results)
  end
end
