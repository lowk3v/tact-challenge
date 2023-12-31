import "@stdlib/deploy";
import "@stdlib/ownable";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Token prices must be decimalized for accuracy, so it is the prices that must be adjusted to decimal 1e9.
  Decimals are only needed for price accuracy. It should be set as 1e9.
  test: So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  Example formula for amountOfAJettonToSend in B->A swap will be
  (amountOfJettonAOnContract * decimal / amountOfJettonBOnContract) * amountOfTokenBToSwap / decimal

  If smart contract pool doesn't have enough jettons to trade,
  then it should send incoming jettons back to the user. For a clearer explanation,
  let's look at the example we described above (smart contract has 10 of jetton A and 2 of jetton B).
  If user will send 3 jettons B, smart contract should reject the message (because contract does not have 3 * 5 = 15 jettons A)
  and send 3 jettons B back to the user.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and
  one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B)
  is undefined (there are no such tests).
  
  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

// To simplify the testing process and the specificity of the messages being sent, we decided to add clear default values in this transaction
message(0xf8a7ea5) TokenTransfer {
     queryId: Int as uint64; // should be 0
     amount: Int as coins; // should be amount of jettons to send
     destination: Address; // should be user address / TokenNotification.from
     responseDestination: Address?; // should be myAddress()
     customPayload: Cell?; // should be null
     forwardTonAmount: Int as coins; // should be ton("0.01")
     forwardPayload: Slice as remaining; // should be emptySlice()
}

contract Task3 with Deployable {
  owner: Address;
  aAmount: Int;
  bAmount: Int;
  jettonAddressA: Address;
  jettonAddressB: Address;
  decimal: Int;

  init(admin: Address, newJettonAddressA: Address, newJettonAddressB: Address) {
    self.owner = admin;
    self.jettonAddressA = newJettonAddressA;
    self.jettonAddressB = newJettonAddressB;
    self.aAmount = 0;
    self.bAmount = 0;
    self.decimal = 1000000000;
  }

  receive(msg: TokenNotification) {
    let receivedA: Bool = context().sender == self.jettonAddressA;
    let receivedB: Bool = context().sender == self.jettonAddressB;

    if (msg.from == self.owner) {
      if (receivedA) {
          self.aAmount = self.aAmount + msg.amount;
      } else if (receivedB) {
          self.bAmount = self.bAmount + msg.amount;
      } else {
        throw(10);
      }
    } else {

      if (receivedA) {
        // A -> B
        let toSend: Int = (self.bAmount * self.decimal / self.aAmount) * msg.amount / self.decimal;
        if (toSend > self.bAmount) {
          self.sendTo(self.jettonAddressA, msg.from, msg.amount);
        } else {
          self.bAmount = self.bAmount - toSend;
          self.aAmount = self.aAmount + msg.amount;
          self.sendTo(self.jettonAddressB, msg.from, toSend);
        }
      } else if (receivedB) {
        // B -> A
        let toSend: Int = (self.aAmount * self.decimal / self.bAmount) * msg.amount / self.decimal;
        if (toSend > self.aAmount) {
          self.sendTo(self.jettonAddressB, msg.from, msg.amount);
        } else {
          self.aAmount = self.aAmount - toSend;
          self.bAmount = self.bAmount + msg.amount;
          self.sendTo(self.jettonAddressA, msg.from, toSend);
        }
      } else {
        throw(10);
      }
    }
  } 

  fun sendTo(token: Address, to: Address, amount: Int) {
    send(SendParameters{
        to: token, 
        value: 0,
        mode: SendRemainingValue + SendIgnoreErrors, 
        bounce: true,
        body:  TokenTransfer {
            queryId: 0,
            amount: amount,
            destination: to,
            responseDestination: myAddress(),
            customPayload: null,
            forwardTonAmount: ton("0.01"),
            forwardPayload: emptySlice()
        }.toCell()
      });
  }
  
  get fun price(jetton: Address): Int { 
    // one more to get the price of jetton A or jetton B.
    if (jetton == self.jettonAddressA) {
      // A -> B
      return self.bAmount * self.decimal / self.aAmount;
    } 
    // B -> A
    return self.aAmount * self.decimal / self.bAmount;
  }
  
  get fun balance(jetton: Address): Int { 
    // Implement a getter that returns the number of jettons in the pool and
    // one more to get the price of jetton A or jetton B.
    if (jetton == self.jettonAddressA) {
      return self.aAmount;
    } else if (jetton == self.jettonAddressB) {
      return self.bAmount;
    } 
    throw(11);
    return 0;
  }

}
