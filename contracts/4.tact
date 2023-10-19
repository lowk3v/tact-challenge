import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining; 
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

message NftWithdrawal {
  queryId: Int as uint64;
  nftAddress: Address;
}

  message(0xd53276db) Excesses {
    query_id: Int as uint64;
  }

  

contract Task4 with Deployable {
  seed: Int as uint128;
  timeToLock: Int as uint32;
  nftAddress: Address;
  preOwnerNft: Address;
  isLocked: Bool;

  const minTonsForStorage: Int = ton("0.03");
  const gasConsumption: Int = ton("0.03");
  
  init(seed: Int) {
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
    self.timeToLock = 1;
    self.nftAddress = newAddress(0, 0);
    self.preOwnerNft = newAddress(0, 0);
    self.isLocked = false;
  }

  receive(msg: Excesses) {
      send(SendParameters{value: 0, to: self.preOwnerNft, mode: SendRemainingValue + SendIgnoreErrors});
  }

  receive(msg: OwnershipAssigned) {
    let msgValue: Int = context().value; // Check the gasCost for storage
    let tonBalanceBeforeMsg: Int = myBalance() - msgValue;
    let storageFee: Int = self.minTonsForStorage - min(tonBalanceBeforeMsg, self.minTonsForStorage);
    msgValue = msgValue - (storageFee + self.gasConsumption);
    require(!self.isLocked, "NFT is already locked");

    self.nftAddress = context().sender;
    self.timeToLock = now() + msg.forwardPayload.loadUint(32);
    self.preOwnerNft = msg.prevOwner;
    self.isLocked = true;
  
    // if (self.isLocked) {
    //   send(SendParameters{
    //     to: context().sender,
    //     value: 0,
    //     mode: SendIgnoreErrors,
    //     bounce: true,
    //     body: Transfer{
    //       queryId: msg.queryId,
    //       newOwner: context().sender,
    //       responseDestination: myAddress(),
    //       customPayload: emptyCell(),
    //       forwardAmount: ton("0.5"),
    //       forwardPayload: emptySlice()
    //     }.toCell()
    //   });
    // } 
    // else {
    //   self.nftAddress = context().sender;
    //   self.timeToLock = now() + msg.forwardPayload.loadUint(32);
    //   self.preOwnerNft = msg.prevOwner;
    //   self.isLocked = true;
    // }
  }

  receive(msg: NftWithdrawal) {
    require(context().sender == self.preOwnerNft, "Invalid sender");
    require(self.nftAddress == msg.nftAddress, "NFT is not locked");
    if (self.timeToLock >= now()) {
      self.reply("NFT is still locked".asComment());
      return;
    } 
    
    send(SendParameters{
        to: self.nftAddress,
        value: 0,
        mode: SendRemainingValue + SendIgnoreErrors,
        bounce: true,
        body: Transfer{
          queryId: msg.queryId,
          newOwner: self.preOwnerNft,
          responseDestination: myAddress(),
          customPayload: emptyCell(),
          forwardAmount: ton("0.5"),
          forwardPayload: emptySlice()
        }.toCell()
    });

    // clear
    self.nftAddress = newAddress(0, 0);
    self.timeToLock = 1;
    self.preOwnerNft = newAddress(0, 0);
    self.isLocked = false;
  }



  get fun time(): Int {
    require(self.isLocked, "NFT is not locked");
    return self.timeToLock - now();
  }

  get fun nft(): Address? {
    require(self.isLocked, "NFT is not locked");
    return self.nftAddress;
  }

  get fun owner(): Address? {
    require(self.isLocked, "NFT is not locked");
    return self.preOwnerNft;
  }
}