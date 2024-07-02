shouldExit = false;
slowExit = false;
isVerbose = true;
ironStart = 0;
furnacePotionCountStart = 0;
smeltingPotionCountStart = 0;
lastFurnacePotionTimer = -1;
lastSmeltingPotionTimer = -1;
smeltingPotionCountStart = 0;
lastSuccessfulPotionLoopTime = 0;
startTime = Date.now();

function toggleMiningMachinary(turnOnMachinary) {
  const machineryList = [
    "drill",
    "crusher",
    "giant_drill",
    "excavator",
    "giant_excavator",
    "massive_excavator",
  ];

  machineryList.forEach((machine) => {
    if (turnOnMachinary) {
      IdlePixelPlus.sendMessage(`MACHINERY=${machine}~increase`);
      IdlePixelPlus.sendMessage(`MACHINERY=${machine}~increase`);
      IdlePixelPlus.sendMessage(`MACHINERY=${machine}~increase`);
    }
    else {
      IdlePixelPlus.sendMessage(`MACHINERY=${machine}~decrease`);
      IdlePixelPlus.sendMessage(`MACHINERY=${machine}~decrease`);
      IdlePixelPlus.sendMessage(`MACHINERY=${machine}~decrease`);
    }
  })
}

function logResources() {
  let ironCreated = var_iron_bar - ironStart;
  let smeltingPotConsumed = smeltingPotionCountStart - var_smelting_upgrade_potion;
  let furnacePotConsumed = furnacePotionCountStart - var_furnace_speed_potion;
  let secondsElapsed = Math.round((Date.now() - startTime) / 1000);

  console.log("Created " + ironCreated + " iron bars in " + secondsElapsed + " seconds. Consumed " + smeltingPotConsumed + " smelting pots and " + furnacePotConsumed + " furance pots");
}

function fastExit(){
  shouldExit = true;
  slowExit = false;
  toggleMiningMachinary(true);
  logResources();
}

function craftingPotionDrinkLoop() {
  let min = 20000, max = 50000;
  let timeout = Math.floor(Math.random() * (max - min + 1) + min);
  let currentdate = new Date(); 
  let requestTime = "Pot request time: "
                + currentdate.getHours() + ":"  
                + currentdate.getMinutes() + ":" 
                + currentdate.getSeconds();

  currentFurnacePotionTimer = var_furnace_speed_potion_timer;
  currentSmeltingPotionTimer = var_smelting_upgrade_potion_timer;
  currentLoopTime = Date.now();

  if (var_smelting_upgrade_potion <= 1 || var_furnace_speed_potion <= 1) {
    console.log("Exiting potion loop fast: only " + var_smelting_upgrade_potion + " remaining and only " + var_furnace_speed_potion + " remaining");
    fastExit();
    return;
  }

  // max potion times are 405 and 270 seconds for furnace and smelting pots
  if (shouldExit) {
    if (slowExit) {
      console.log(requestTime + " Graceful exit requested. Optionally drinking potions to roughly equalize timers");
      if ((var_furnace_speed_potion_timer - var_smelting_upgrade_potion_timer) > 170);
        websocket.send('DRINK=smelting_upgrade_potion');
      if ((var_smelting_upgrade_potion_timer - var_furnace_speed_potion_timer) > 240);
        websocket.send('DRINK=furnace_speed_potion');
    }
    return;
  }

  let isSmeltingUpgradePotTimerLow = currentSmeltingPotionTimer < 200;
  let isFurnaceSpeedPotTimerLow = currentFurnacePotionTimer < 200;
  if(currentFurnacePotionTimer == lastFurnacePotionTimer)
  {
    console.log("WARN: furnace potion timer has not moved on since the last loop:")
    console.log("  Current furance timer is: " + currentFurnacePotionTimer + " and last was: " + lastFurnacePotionTimer)
    let estimatedMillisecondsElapsed = currentLoopTime - lastSuccessfulPotionLoopTime;
    let estimatedPotionTimer = lastFurnacePotionTimer - (estimatedMillisecondsElapsed / 1000)
    let mins = Math.floor(Math.abs(estimatedPotionTimer) / 60);
    let secs = Math.abs(estimatedPotionTimer) % 60;
    console.log("  Esimated timer is: " +  + mins + " mins and " + secs + " secs");
  }
  else if (currentSmeltingPotionTimer == lastSmeltingPotionTimer){
    console.log("WARN: smelting potion has not moved on since the last loop:")
    console.log("  Current smelting timer is: " + currentSmeltingPotionTimer + " and last was: " + lastSmeltingPotionTimer)
    let estimatedMillisecondsElapsed = currentLoopTime - lastSuccessfulPotionLoopTime;
    let estimatedPotionTimer = lastSmeltingPotionTimer - (estimatedMillisecondsElapsed / 1000)
    let mins = Math.floor(Math.abs(estimatedPotionTimer) / 60);
    let secs = Math.abs(estimatedPotionTimer) % 60;
    console.log("  Esimated timer is: " +  + mins + " mins and " + secs + " secs");

  }
  else{

    if (isSmeltingUpgradePotTimerLow) {
      isVerbose && console.log(requestTime + " Smelting upgrade pot timer is: " + currentSmeltingPotionTimer + ". Consuming another potion");
      let mins = Math.floor((Math.abs(currentSmeltingPotionTimer) + 270) / 60);
      let secs = (Math.abs(currentSmeltingPotionTimer) + 270) % 60;
      isVerbose && console.log(" Expected timer is  " + mins + " mins and " + secs + " secs");
      websocket.send('DRINK=smelting_upgrade_potion');
    }
    if (isFurnaceSpeedPotTimerLow) {
      isVerbose && console.log(requestTime + " Furnace speed pot timer is: " + currentFurnacePotionTimer + ". Consuming another potion");
      let mins = Math.floor((Math.abs(currentFurnacePotionTimer) + 405) / 60);
      let secs = (Math.abs(currentFurnacePotionTimer) + 405) % 60;
      isVerbose && console.log(" Expected timer is  " + mins + " mins and " + secs + " secs");
      websocket.send('DRINK=furnace_speed_potion');
    }

    lastFurnacePotionTimer = var_furnace_speed_potion_timer;
    lastSmeltingPotionTimer = var_smelting_upgrade_potion_timer;
    lastSuccessfulPotionLoopTime = Date.now();
  }
  console.log(requestTime + " looping potion drink again. Waiting " + (timeout/1000) + " seconds.");
  setTimeout(craftingPotionDrinkLoop, timeout);
}

function smeltCopperSilverLoop() {
  let min = 250, max = 1200;
  let timeout = Math.floor(Math.random() * (max - min + 1) + min);
  let currentdate = new Date(); 
  let requestTime = "Smelt request time: "
                + currentdate.getHours() + ":"  
                + currentdate.getMinutes() + ":" 
                + currentdate.getSeconds();

  if (var_copper < 10000) {
    console.log("Exiting smelting loop fast: Total copper stonks are low. ");
    fastExit();
    return
  }

  let isSmelting = var_furnace_ore_amount_set != 0;
  let maxSilver = Math.min(Math.floor(var_oil / 15), 5000);
  let maxCopper = 5000;

  let copperSmeltSeconds = Math.ceil((2 * maxCopper) / 1000);
  let silverSmeltSeconds = Math.ceil((9 * maxSilver) / 1000);
  let canSmeltCopper = copperSmeltSeconds < var_smelting_upgrade_potion_timer && copperSmeltSeconds < var_furnace_speed_potion_timer && var_copper > 10000;
  let canSmeltSilver = silverSmeltSeconds < var_smelting_upgrade_potion_timer && silverSmeltSeconds < var_furnace_speed_potion_timer && var_silver > 5000;

  if (shouldExit) {
    if (!slowExit) {
      return;
    }
    console.log(requestTime + " Exiting smelting loop slow: potions still running. Can still smelt copper? " + canSmeltCopper);
  }

  if (!canSmeltCopper) {
    console.log(requestTime + " Exiting smelting loop fast: Can no longer smelt copper.");
    isVerbose && console.log(" Copper smelt seconds: " + copperSmeltSeconds + " < Smelting pot timer " + var_smelting_upgrade_potion_timer + " ?");
    isVerbose && console.log(" Copper smelt seconds: " + copperSmeltSeconds + " < Furnace pot timer " + var_furnace_speed_potion_timer + " ?");
    isVerbose && console.log(" Total copper: " + var_copper + " > " + 10000 + " ?");
    fastExit();
    return;
  }

  if (!isSmelting) {
    if (maxSilver > 4000 && canSmeltSilver) {
      if (canSmeltSilver)
        websocket.send('SMELT=silver~' + maxSilver);
      else
        isVerbose && console.log("Cannot smelt silver");
    }
    else {
      if (canSmeltCopper)
        websocket.send('SMELT=copper~' + maxCopper);
      else
        isVerbose && console.log("Cannot smelt copper");
    }
  }

  setTimeout(smeltCopperSilverLoop, timeout);
}

function startBars() {
  shouldExit = false;
  slowExit = false;
  isVerbose = true;
  startTime = Date.now();
  ironStart = var_iron_bar;
  smeltingPotionCountStart = var_smelting_upgrade_potion;
  furnacePotionCountStart = var_furnace_speed_potion;
  toggleMiningMachinary(false);
  craftingPotionDrinkLoop();
  setTimeout(smeltCopperSilverLoop, 1000);
}

function stopBars() {
  slowExit = true;
  shouldExit = true;
  toggleMiningMachinary(true);
}