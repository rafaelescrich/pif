pragma solidity ^0.4.11;

contract PayItForward {
  struct FrozenEnt {
    uint amount;	// amount deposited in contract, and frozen
    uint thawTime;	// timestamp when amount may be thawed (entry expires)
  }

  FrozenEnt[] internal frozen;	// list of frozen funds
  uint internal nThawed;	// amount thawed
  uint internal lastDraw;	// timestamp of last draw

  uint constant public frozenMin = 60 seconds;  // Minimum time to freeze ETH
  uint constant public frozenDefault = 30 days;	// def. time ETH is frozen
  uint constant public drawMax = 1 ether;	// maximum ETH draw amt.
  uint constant public drawPeriod = 60;		// min. seconds between draws

  // constructor
  function PayItForward() {
    nThawed = 0;
    lastDraw = now - drawPeriod - 1;
  }

  // Freeze received ETH, for later thawing and withdrawal at time >= thawTime
  function freeze(uint thawTime_) payable {
    require(msg.value > 0);
    require(thawTime_ >= (now + frozenMin));

    frozen.push(FrozenEnt({
      amount:	msg.value,
      thawTime:	thawTime_,
    }));
  }

  // Freeze received ETH, for later thawing and withdrawal
  function() payable {
    freeze(now + frozenDefault);
  }

  // Return balance frozen
  function balanceFrozen() constant returns (uint) {
    // Sum all frozen entries not yet expired
    uint tmpBal = 0;
    for (uint i = 0; i < frozen.length; i++) {
      if (frozen[i].thawTime > now)
        tmpBal += frozen[i].amount;
    }

    return tmpBal;
  }

  // Return balance thawed
  function balanceThawed() constant returns (uint) {
    // Sum thawed ETH
    uint tmpBal = nThawed;

    // Sum all expired frozen entries
    for (uint i = 0; i < frozen.length; i++) {
      if (frozen[i].thawTime <= now)
        tmpBal += frozen[i].amount;
    }

    return tmpBal;
  }

  // Return maximum balance that may be withdrawn
  function balanceDrawable() constant returns (uint) {
    // Determine total thawed balance
    uint drawable = balanceThawed();

    // Clamp balance to max per draw
    if (drawable > drawMax)
      drawable = drawMax;

    // Draw rate limiting
    if (lastDraw > (now - drawPeriod))
      drawable = 0;

    return drawable;
  }

  // Thaw ETH, if any
  function housekeeping() returns (bool success) {
    // Move thawed funds out of frozen list
    while ((frozen.length > 0) &&
           (frozen[0].thawTime < now)) {
      nThawed += frozen[0].amount;
      delete frozen[0];
    }

    return true;
  }

  // Withdraw thawed ETH to anyone who requests it
  function transfer(address to, uint value) returns (bool success) {
    // Value size limiting
    require(value > 0);
    require(value <= balanceDrawable());

    // Draw rate limiting
    require(lastDraw < (now - drawPeriod));

    // Housekeeping: move thawed funds out of frozen list
    this.housekeeping();

    // Withdraw value from contract
    nThawed -= value;
    lastDraw = now;
    to.transfer(value);

    return true;
  }
}

