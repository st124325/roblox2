# Архитектура Этапа 1 (контракт модулей)

Каждый модуль пишет один исполнитель и трогает только свои файлы. Остальные модули вызывает строго по API ниже.
Стиль: Luau со `--!strict` не обязателен, табы, комментарии на английском, как в `src/shared/*`.
Все числа геймплея — в `Config` (добавлять новые ключи можно, менять смысл старых нельзя).
Всё строится кодом из Part/MeshPart-примитивов, никаких ассетов из Toolbox.

## Дерево

```
src/shared/
  Config.luau  Format.luau  Net.luau        (есть)
  Kaiju.luau                                 каталог кайдзю
  KaijuModel.luau                            сборка модели кайдзю из частей
src/server/
  Main.server.luau                           бутстрап: Map.build(); Data.init(); Bases.init(); Conveyor.init(); Carry.init()
  Data.luau                                  сохранения с session lock
  Map.luau                                   карта: конвейер, 8 баз, спавны
  Bases.luau                                 владение базами, слоты, доход, рост, сбор, замок, продажа, ребёрт
  Conveyor.luau                              лента, спавн по весам редкости, покупка
  Carry.luau                                 переноска, кражи, доставка, бита Bonk
src/client/
  Main.client.luau                           HUD, уведомления, "+$", кнопки Домой/Ребёрт
```

## shared/Kaiju.luau
```lua
Kaiju.Rarities = { "Common","Rare","Epic","Legendary","Mythic","Secret" }
Kaiju.RarityColor: { [string]: Color3 }
Kaiju.List: { KaijuDef }   -- 24+ штук, по 3–6 на редкость, мемные имена (Тостозавр, Гоблин-Бубльгум, Жирафокран...)
type KaijuDef = { Id: string, Name: string, Rarity: string, Price: number, Income: number, -- $/s на стадии S
                  Body: Color3, Accent: Color3, Shape: string }  -- Shape: "Dino"|"Blob"|"Crab"|"Bird"|"Tall"
Kaiju.get(id): KaijuDef?
Kaiju.roll(rng: Random): KaijuDef      -- по Config.RarityWeights, затем равномерно внутри редкости
Kaiju.incomeOf(entry: SlotEntry, rebirths: number): number  -- def.Income * stage.Income * Config.incomeMultiplier
```
Окупаемость: Price / Income ≈ 20–60 с для Common, растёт с редкостью. Цены от $15 до ~$50M.

## shared/KaijuModel.luau
```lua
KaijuModel.build(def: KaijuDef, scale: number, mutation: string?): Model
-- PrimaryPart "Root" (Anchored=false, CanCollide=false, Massless), все части сварены к Root,
-- низ модели на уровне Root.Position.Y - Root.Size.Y/2. Над головой BillboardGui "Tag":
-- имя, редкость (цвет RarityColor), "$X/s" (Label "Income"), стадия (Label "Stage").
KaijuModel.setInfo(model, incomeText: string, stageText: string)
```

## server/Data.luau
```lua
type SlotEntry = { Id: string, Growth: number, Mutation: string? } -- Growth: секунды на базе
type Profile = { Money: number, Rebirths: number, Slots: { [number]: SlotEntry }, -- ключи "1".."12" при сохранении
                 Bank: number, LastOnline: number, Stats: { Bought: number, Stolen: number, Lost: number } }
Data.init()                    -- PlayerAdded/Removing, BindToClose, автосейв каждые 60 с
Data.get(player): Profile?     -- nil пока не загружен
Data.loaded: BindableEvent     -- :Fire(player, profile) после загрузки (Event для подписки)
Data.addMoney(player, n)       -- обновляет Profile.Money и атрибут player:SetAttribute("Money", n)
```
Session lock через UpdateAsync (поле lock = {JobId, time}, протухает через 30 мин), ретраи, в Studio без API —
работать в памяти. Атрибуты на Player: Money, Rebirths, Income ($/s), BaseIndex.

## server/Map.luau
```lua
Map.build()
Map.Bases: { BaseInfo }   -- 8 штук: 4 слева от ленты, 4 справа
type BaseInfo = { Index: number, Model: Model, Pads: { BasePart },   -- Config.MaxSlots площадок
                  CollectPlate: BasePart, LockButton: BasePart, Barrier: BasePart, -- Barrier CanCollide=false, прозрачный
                  Zone: BasePart,    -- невидимый объём базы (для "игрок у себя на базе")
                  Sign: BasePart,    -- табличка с SurfaceGui, Label "Owner"
                  Spawn: CFrame }
Map.Belt: { Start: Vector3, Finish: Vector3, Part: BasePart }  -- лента вдоль оси X, длина Config.BeltLength
Map.Lobby: CFrame  -- спавн до назначения базы
```

## server/Bases.luau
```lua
Bases.init()                       -- назначает базу на Data.loaded, освобождает при выходе
Bases.baseOf(player): BaseInfo?
Bases.ownerOf(base: BaseInfo): Player?
Bases.addKaiju(player, entry: SlotEntry): number?   -- первый свободный разблокированный слот, nil если нет места
Bases.removeKaiju(player, slot: number): SlotEntry? -- убирает модель с площадки
Bases.slotModel(player, slot): Model?               -- модель на площадке (для кражи: ProximityPrompt "Steal" вешает Carry)
Bases.isLocked(base): boolean
Bases.kaijuAdded: BindableEvent    -- Fire(player, slot, model) — Carry вешает на модель промпты
Bases.unlockedSlots(player): number -- Config.StartSlots + Rebirths*SlotsPerRebirth, max MaxSlots
```
Доход: каждые Config.IncomeTick Growth += tick, доход идёт в Profile.Bank; касание CollectPlate переводит Bank в Money
(Net "Cash"). Оффлайн: при загрузке Bank += min(now-LastOnline, cap) * income * OfflineRate. Рост меняет Scale модели.
Замок: касание LockButton хозяином → Barrier на Config.LockSeconds выталкивает чужих (не-владелец внутри Zone
отбрасывается). Продажа: ProximityPrompt "Sell" на своих кайдзю (только хозяину, через клиентскую видимость — либо
сервер отклоняет). Ребёрт: Net "Rebirth", цена Config.rebirthCost, обнуляет Money и Slots, +1 Rebirths.
Net "GoHome": телепорт на Spawn, кулдаун Config.HomeCooldown.

## server/Conveyor.luau
```lua
Conveyor.init()   -- каждые Config.BeltSpawnSeconds Kaiju.roll → модель едет по Map.Belt (анкерная, TweenService/Heartbeat)
```
ProximityPrompt "Buy $X": списывает Money, Bases.addKaiju (если нет места — отказ Notify), модель с ленты удаляется.
Кайдзю, доехавший до конца, исчезает. Купленный сразу стоит на базе (без переноски) — переноска только для краж.

## server/Carry.luau
```lua
Carry.init()
Carry.isCarrying(player): boolean
```
Подписка на Bases.kaijuAdded: на модель вешается ProximityPrompt "Steal" (HoldDuration Config.StealHoldSeconds),
не работает для владельца и если база владельца заблокирована. При краже: Bases.removeKaiju(owner, slot), модель
сваривается над головой вора, WalkSpeed = Config.WalkSpeed * stage.Carry, Net "Robbed" владельцу.
Доставка: вор вошёл в Zone своей базы → Bases.addKaiju(thief, entry) (Growth сохраняется), Stats.Stolen++.
Нет места / смерть / удар битой / Config.CarryTimeoutSeconds → кайдзю возвращается владельцу (или в первый свободный
слот; если владелец вышел — пропадает).
Бита "Bonk": Tool в Backpack каждому, удар в радиусе Config.BonkRange, кулдаун, оглушение (WalkSpeed 0 на
Config.BonkStunSeconds) и выбивание переносимого кайдзю.

## client/Main.client.luau
HUD на ScreenGui из кода: деньги (атрибут Money, Format.money), доход/с (атрибут Income), ребёрты,
кнопки "Домой" (Net GoHome) и "Rebirth (цена)" (Net Rebirth), тосты по Net Notify/Robbed, всплывающие "+$" по Net Cash.
Адаптив под мобильные (UIScale / относительные размеры).

## Remotes
Новые имена добавляются в `EVENTS` в `src/shared/Net.luau` (с комментарием направления). Уже есть: Notify, GoHome,
Rebirth, Robbed, Cash.
