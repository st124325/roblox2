# Модели монстров

**Ultimate Monsters Bundle** от [Quaternius](https://quaternius.com/packs/ultimatemonsters.html), лицензия CC0
(общественное достояние: можно в коммерческой игре, указывать автора не обязательно, но приятно).
Источник: официальная папка Google Drive со страницы пака. Превью всего набора — `Preview.jpg`.

50 FBX с анимациями (idle, walk, run, attack, jump, death…), текстура одна на всех — `Atlas_Monsters.png`.
- `Blob_*` — круглые малыши (~0.3 МБ), подходят для Common/Rare
- `Flying_*` — летающие (~0.7–2 МБ), Rare/Epic
- `Big_*` — крупные гуманоиды (~3.4 МБ), Legendary и выше; `*_Evolved` — улучшенные версии

## Черновая раскладка по кайдзю (`src/shared/Kaiju.luau`)
| Редкость | Кайдзю → модель |
|---|---|
| Common | toastosaurus → Blob_Mushnub · mudpup → Blob_Dog · craboid → Blob_GreenSpikyBlob · chirik → Blob_Chicken · nosatik → Blob_Fish |
| Rare | cactusaur → Blob_Cactoro · bubblegum_goblin → Blob_PinkBlob · crabburger → Blob_Orc · pigeon_bomber → Flying_Pigeon · giraffecrane → Flying_Alpaking |
| Epic | pelmenisaur → Blob_Mushnub_Evolved · slime_shlepa → Blob_GreenBlob · boxer_crab → Flying_Armabee · interceptor_seagull → Blob_Birb · bananosaur → Flying_Glub |
| Legendary | catzilla → Blob_Cat · avocado_monster → Big_Frog · king_crab → Big_MushroomKing · grill_phoenix → Flying_Dragon |
| Mythic | mecha_godzilych → Big_Dino · black_hole_blob → Flying_Ghost · crab_armageddon → Flying_Demon · shawarmasaur → Big_Cactoro |
| Secret | cosmo_capybara → Big_Alien · giga_shlepa → Big_Yeti · baton_dragon → Flying_Dragon_Evolved · cyber_titan_rex → Big_BlueDemon |

## Как попасть в игру
Roblox не читает FBX из кода: каждую модель нужно один раз загрузить как ассет и сослаться на её ID.
1. Studio → Avatar/Home → **Import 3D** → выбрать FBX (можно пачкой) → сохранить в ReplicatedStorage/KaijuModels,
   **или** загрузить через Open Cloud Assets API (`POST /assets/v1/assets`, тип Model) ключом с правом `asset:write`.
2. `KaijuModel.build` клонирует модель по `Id` кайдзю вместо сборки из частей (текущая сборка из частей остаётся запасным вариантом).
