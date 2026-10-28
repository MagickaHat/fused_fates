#================================================================================================
# Pokémon Fused Fates Underground System - 007_Spheres.rb
#================================================================================================

#==================================================================
# module Underground
#==================================================================
module Underground
  #==================================================================
  # module Spheres
  #==================================================================
  # @brief Growing spheres in planters, and trading spheres for goods and
  # statues (and selling them back).
  #
  # A buried sphere is a single sphere of some size (its unit count). It
  # grows by one every SPHERE_GROWTH_STEPS steps taken in the Underground,
  # up to SPHERE_MAX_SIZE, and is dug back up for its current size.
  module Spheres
    module_function

    #----------------------------------------------------------------
    # Planters
    #----------------------------------------------------------------
    # @brief How many spheres can be buried at once: PLANTER_CAPACITY per
    # planter placed in the base.
    # @return [Integer]
    def capacity
      planters = Underground.data.placed_goods.count { |id| GameData::UndergroundGood.try_get(id)&.use == :planter }
      return planters * UndergroundSettings::PLANTER_CAPACITY
    end

    # @brief Buries a sphere.
    # @param color [Symbol]
    # @param size [Integer] Units taken from the player.
    # @return [Boolean] false if the player lacks the units or there's no room.
    def bury(color, size)
      d = Underground.data
      return false if size <= 0 || d.spheres[color] < size || d.buried.length >= capacity
      d.spheres[color] -= size
      d.buried.push({ color: color, size: size, start_size: size, steps: 0 })
      return true
    end

    # @brief Digs a buried sphere back up.
    # @param index [Integer] Index in the buried list.
    # @return [Hash, nil] The buried entry, or nil if there is none.
    def dig_up(index)
      d = Underground.data
      entry = d.buried.delete_at(index)
      return nil unless entry
      Underground.add_spheres(entry[:color], entry[:size])
      d.stats[:spheres_grown] += 1 if entry[:size] > entry[:start_size]
      return entry
    end

    # @brief Grows every buried sphere by one step.
    def step
      Underground.data.buried.each do |entry|
        next if entry[:size] >= UndergroundSettings::SPHERE_MAX_SIZE
        entry[:steps] += 1
        next if entry[:steps] < UndergroundSettings::SPHERE_GROWTH_STEPS
        entry[:steps] = 0
        entry[:size] += 1
      end
    end

    # @brief Menu text for a buried sphere.
    # @param entry [Hash]
    # @return [String]
    def entry_text(entry)
      text = _INTL("{1} (size {2})", Underground.sphere_name(entry[:color]), entry[:size])
      text += _INTL(" - fully grown") if entry[:size] >= UndergroundSettings::SPHERE_MAX_SIZE
      return text
    end

    # @brief The planter menu: bury spheres and dig them up.
    def planter_menu
      d = Underground.data
      loop do
        cmds = d.buried.map { |e| entry_text(e) }
        cmds.push(_INTL("Bury a sphere")) if d.buried.length < capacity
        cmds.push(_INTL("Cancel"))
        msg = _INTL("Planter ({1}/{2} buried)", d.buried.length, capacity)
        choice = pbMessage(msg, cmds, -1)
        break if choice < 0 || choice == cmds.length - 1
        if choice < d.buried.length
          next unless pbConfirmMessage(_INTL("Dig up the {1}?", entry_text(d.buried[choice])))
          entry = dig_up(choice)
          pbMessage(_INTL("You dug up {1} {2} units!", entry[:size], Underground.sphere_name(entry[:color])))
        else
          bury_menu
        end
      end
    end

    # @brief Lets the player choose a sphere color and size to bury.
    def bury_menu
      d = Underground.data
      colors = GameData::UndergroundSphere.keys.select { |c| d.spheres[c] > 0 }
      if colors.empty?
        pbMessage(_INTL("You don't have any spheres to bury."))
        return
      end
      cmds = colors.map { |c| _INTL("{1} x{2}", Underground.sphere_name(c), d.spheres[c]) }
      cmds.push(_INTL("Cancel"))
      choice = pbMessage(_INTL("Bury which sphere?"), cmds, -1)
      return if choice < 0 || choice >= colors.length
      color = colors[choice]
      most = [d.spheres[color], UndergroundSettings::SPHERE_MAX_SIZE - 1].min
      params = ChooseNumberParams.new
      params.setRange(1, most)
      params.setDefaultValue(1)
      params.setCancelValue(0)
      size = pbMessageChooseNumber(_INTL("How big a sphere? (1-{1})", most), params)
      return if size <= 0
      pbMessage(_INTL("You buried a size {1} {2}.", size, Underground.sphere_name(color))) if bury(color, size)
    end

    #----------------------------------------------------------------
    # Traders
    #----------------------------------------------------------------
    # @brief Wares a trader is able to stock at the player's mission stage.
    # @param trader_id [Symbol]
    # @return [Array<Symbol>]
    def available_wares(trader_id)
      fused_ok = Underground.data.mission_stage >= UndergroundSettings::FUSED_TRADER_STAGE
      wares = GameData::UndergroundTrader.try_get(trader_id)&.wares || []
      return wares.select do |id|
        next GameData::UndergroundGood.exists?(id) unless Underground.statue?(id)
        next fused_ok || GameData::UndergroundStatue.get(id).tier != :fused
      end
    end

    # @brief Today's stock for a trader, rolled the first time it's asked for.
    # @param trader_id [Symbol]
    # @return [Hash] { ware_id => sold? }
    def stock(trader_id)
      d = Underground.data
      d.trader_stock[trader_id] ||= begin
        rng = DailyRefresh.seeded_rng(d.day_key, trader_id, d.mission_stage, "trader")
        wares = available_wares(trader_id).shuffle(random: rng).first(UndergroundSettings::TRADER_STOCK_SIZE)
        wares.to_h { |id| [id, false] }
      end
      return d.trader_stock[trader_id]
    end

    # @brief What a ware costs at a trader.
    # @param trader_id [Symbol]
    # @param ware [Symbol]
    # @return [Hash] { color => units }
    def price(trader_id, ware)
      custom = GameData::UndergroundTrader.try_get(trader_id)&.prices&.[](ware)
      return custom if custom
      return UndergroundSettings::STATUE_PRICES[GameData::UndergroundStatue.get(ware).tier] if Underground.statue?(ware)
      return UndergroundSettings::GOOD_PRICE
    end

    # @brief Buys a ware from a trader.
    # @param trader_id [Symbol]
    # @param ware [Symbol]
    # @return [Boolean] false if it's sold out or unaffordable.
    def buy(trader_id, ware)
      wares = stock(trader_id)
      return false if wares[ware] != false
      return false unless Underground.spend(price(trader_id, ware))
      wares[ware] = true
      Underground.grant_ware(ware)
      Underground.data.stats[:trades] += 1
      return true
    end

    # @brief What a trader pays to buy a ware back: SELL_BACK_RATE percent of
    # its price, rounded down per color but never below 1.
    # @param trader_id [Symbol]
    # @param ware [Symbol]
    # @return [Hash] { color => units }
    def sell_price(trader_id, ware)
      rate = UndergroundSettings::SELL_BACK_RATE
      return price(trader_id, ware).to_h { |color, units| [color, [units * rate / 100, 1].max] }
    end

    # @brief Wares a trader is willing to buy back.
    # @param trader_id [Symbol]
    # @return [Array<Symbol>]
    def buys(trader_id)
      return GameData::UndergroundTrader.try_get(trader_id)&.buys || []
    end

    # @brief Wares in storage that a trader will buy. Placed statues and goods
    # must be taken back into storage first.
    # @param trader_id [Symbol]
    # @return [Array<Symbol>]
    def sellable(trader_id)
      return buys(trader_id).select { |id| Underground.storage_for(id)[id] > 0 }
    end

    # @brief Sells one ware from storage to a trader.
    # @param trader_id [Symbol]
    # @param ware [Symbol]
    # @return [Boolean] false if the trader doesn't buy it or none are in storage.
    def sell(trader_id, ware)
      return false unless sellable(trader_id).include?(ware)
      d = Underground.data
      store = Underground.storage_for(ware)
      store[ware] -= 1
      store.delete(ware) if store[ware] <= 0
      sell_price(trader_id, ware).each { |color, units| Underground.add_spheres(color, units) }
      d.stats[:sold] += 1
      return true
    end

    # @brief The trader menu: trade spheres for wares, or sell wares back.
    # @param trader_id [Symbol]
    def trader_menu(trader_id)
      trader = GameData::UndergroundTrader.try_get(trader_id)
      return unless trader
      pbMessage(_INTL("{1}: Got spheres? I've got things to trade.", trader.name))
      loop do
        choice = pbMessage(_INTL("What'll it be?"), [_INTL("Trade spheres"), _INTL("Sell"), _INTL("Cancel")], -1)
        case choice
        when 0 then buy_menu(trader_id)
        when 1 then sell_menu(trader_id)
        else        break
        end
      end
      pbMessage(_INTL("{1}: Come back tomorrow for new stock!", trader.name))
    end

    # @brief Lets the player sell wares from storage to a trader.
    # @param trader_id [Symbol]
    def sell_menu(trader_id)
      trader = GameData::UndergroundTrader.get(trader_id)
      loop do
        ids = sellable(trader_id)
        if ids.empty?
          pbMessage(_INTL("{1}: You don't have anything I'd buy. (Placed items need to be taken back first.)",
                          trader.name))
          break
        end
        cmds = ids.map do |id|
          _INTL("{1} x{2} - {3}", Underground.ware_name(id), Underground.storage_for(id)[id],
                Underground.price_text(sell_price(trader_id, id)))
        end
        cmds.push(_INTL("Cancel"))
        choice = pbMessage(_INTL("What will you sell?"), cmds, -1)
        break if choice < 0 || choice >= ids.length
        ware = ids[choice]
        pay = sell_price(trader_id, ware)
        next unless pbConfirmMessage(_INTL("Sell the {1} for {2}?", Underground.ware_name(ware),
                                           Underground.price_text(pay)))
        sell(trader_id, ware)
        pbMessage(_INTL("You got {1}!", Underground.price_text(pay)))
      end
    end

    # @brief Lets the player trade spheres for today's stock.
    # @param trader_id [Symbol]
    def buy_menu(trader_id)
      trader = GameData::UndergroundTrader.get(trader_id)
      loop do
        wares = stock(trader_id)
        if wares.empty?
          pbMessage(_INTL("{1}: I've got nothing for you today.", trader.name))
          break
        end
        ids = wares.keys
        cmds = ids.map do |id|
          next _INTL("{1} (traded)", Underground.ware_name(id)) if wares[id]
          next _INTL("{1} - {2}", Underground.ware_name(id), Underground.price_text(price(trader_id, id)))
        end
        cmds.push(_INTL("Cancel"))
        choice = pbMessage(_INTL("What would you like?"), cmds, -1)
        break if choice < 0 || choice >= ids.length
        ware = ids[choice]
        if wares[ware]
          pbMessage(_INTL("You already traded for that today."))
          next
        end
        cost = price(trader_id, ware)
        unless Underground.can_afford?(cost)
          pbMessage(_INTL("You need {1} for that.", Underground.price_text(cost)))
          next
        end
        next unless pbConfirmMessage(_INTL("Trade {1} for the {2}?", Underground.price_text(cost),
                                           Underground.ware_name(ware)))
        buy(trader_id, ware)
        pbMessage(_INTL("You got the {1}! It went into storage.", Underground.ware_name(ware)))
      end
    end
  end
end

# @brief Opens the planter menu (also reached by using a placed Planter good).
def pbUndergroundPlanter
  if Underground::Spheres.capacity <= 0
    pbMessage(_INTL("You need a Planter in your Secret Base to grow spheres."))
    return
  end
  Underground::Spheres.planter_menu
end

# @brief Trader event.
# @param trader_id [Symbol] A section of underground_traders.txt.
def pbUndergroundTrader(trader_id)
  Underground::Spheres.trader_menu(trader_id)
end

EventHandlers.add(:on_player_step_taken, :underground_sphere_growth,
  proc {
    next unless Underground.in_underground?
    Underground::Spheres.step
  }
)
