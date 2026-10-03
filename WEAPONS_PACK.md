# Advanced Weapons — იარაღების პაკეტი და როგორ შევიტანოთ თამაშში

დოკუმენტი 2026-10-03-ს დაიწერა, პაკეტის ჩამოტვირთვისთანავე. ახალი სესია აქედან
იწყებს. ზომები და პივოტები FBX-იდან Blender-ით არის ამოღებული (Normal ნაკრები).

- **პაკეტი:** „Low-Poly Medieval Fantasy – Advanced Weapons“ (Polysplit Games), v1.0.0, ნაყიდია 2026-10-03.
  Standard Unity Asset Store EULA: თამაშის ნაწილად გამოიყენება, ცალკე არ ვრცელდება.
- **სად არის:**
  - გახსნილი: `~/Projects/vepxis-art/packs/advanced_weapons/Assets/PolysplitGames/LowPolyMedievalFantasyAdvancedWeapons/`
  - ორიგინალი: `~/Projects/vepxis-art/packs/Low-Poly Medieval Fantasy - Advanced Weapons.unitypackage`
    (და `~/Library/Unity/Asset Store-5.x/Polysplit Games/3D ModelsPropsWeapons/`)
  - იქვეა მონსტრების პაკეტიც, გახსნილი: `packs/biped_creatures/` (იხ. `CREATURES_PACK.md`).
- **რეპოში ჯერ არაფერია.** თამაშში მხოლოდ ის შევა, რასაც თამაში ტვირთავს (glb-ები, ტექსტურა), `assets/weapons/`-ში.

## 1. რა არის შიგნით

31 იარაღი × 4 სტილი = 124 FBX:

| სტილი | საქაღალდე |
| --- | --- |
| ჩვეულებრივი | `AdvancedWeapons/Normal/` |
| მოოქროვილი | `AdvancedWeapons/Ornate/` (`*_Ornate`) |
| ობსიდიანი | `AdvancedWeapons/Obsidian/` (`*_Obsidian`) |
| ძვლის | `AdvancedWeapons/Bone/` (`*_Bone`) |

ყოველ FBX-ს თავისი prefab აქვს `prefabs/<სტილი>/`-ში. ჩვენთვის prefab-ები საჭირო არ არის.

**ტექსტურები** (`Materials_Shaders_Textures/`):
- `WeaponPreColoredTextures/medievalTexture_{normal,ornate,obsidian,bone}_col.png`: **წინასწარ შეღებილი**, თითო სტილს თითო. ეს ავიღოთ, ასე ყველაზე მარტივია.
- `genericRGB_medievalTexture 1.png` + `RGBRecolor_AdvancedWeapons.shadergraph`: RGB ნიღაბი ფერის შესაცვლელად, იგივე სისტემა, რაც მონსტრებს აქვთ (`CREATURES_PACK.md` §4). საჭიროა მხოლოდ მაშინ, თუ საკუთარი ფერები გვინდა.
- მასალის სახელი FBX-ში `genericRGBMat_Objects`-ია. `Axe`, `Spear`, `Wand`-ს `lambert1` აქვს, ამიტომ ტექსტურა ხელით უნდა მიენიჭოს.

## 2. იარაღები (Normal), ზომები მეტრებში

**პივოტი სახელურზეა** (0,0,0 ≈ მუშტის ადგილი). პირი ან ტარი **−Y**-ისკენაა, ტარის ბოლო +Y-ზე.
სიგრძე = Y ზომა. გმირი ≈1.8–1.95 მ-ია.

| იარაღი | ფაილი | სიგრძე | სამკუთხ. | შენიშვნა |
| --- | --- | ---: | ---: | --- |
| ხანჯალი | `Dagger_Set` | 0.71 | 113 | + ქარქაში (`Dagger_Scabbard`) |
| მოკლე ხმალი | `ShortSword_Set` | 0.96 | 105 | + ქარქაში |
| მრუდე ხმალი | `CurvedSword_Set` | 1.23 | 119 | + ქარქაში |
| რაპირა | `Rapier_Set` | 1.34 | 170 | + ქარქაში |
| გრძელი ხმალი | `LongSword_Set` | 1.42 | 125 | + ქარქაში |
| ორხელა ხმალი | `GreatSword_Set` | 2.18 | 191 | + ქარქაში, **დიდია** |
| მრუდე ორხელა | `CurvedGreatSword_Set` | 2.13 | 165 | + ქარქაში |
| ცული | `Axe` | 0.86 | 99 | `lambert1` |
| დიდი ცული | `GreatAxe` | 1.32 | 196 | |
| ჩაქუჩი | `Hammer` | 0.74 | 112 | |
| დიდი ჩაქუჩი | `GreatHammer` | 1.22 | 280 | |
| გურზი | `Mace` | 0.93 | 278 | |
| შუბ-გურზი | `MorningStar` | 0.91 | 318 | |
| ჯაჭვიანი გურზი | `Flail` | 1.79 | 579 | **რიგიანი** (ჯაჭვი ძვლებზე) |
| შუბი | `Spear` | 2.93 | 124 | `lambert1`, პივოტი შუაშია (ტარი +0.96-მდე) |
| ჰალბერდი | `Poleaxe` | 3.06 | 181 | პივოტი შუაშია |
| კვერთხი | `Staff` | 1.86 | 384 | პივოტი შუაშია (+1.01-მდე) |
| ჯადოსნური ჯოხი | `Wand` | 0.71 | 110 | `lambert1` |
| მრგვალი ფარი | `RoundShield` | Ø0.68 | 341 | |
| სამკუთხა ფარი | `KiteShield` | 0.97 | 118 | |
| დიდი ფარი | `TowerShield` | 1.61 | 152 | |
| მშვილდი | `Bow` | 2.11 სიგანე | 166 | **რიგიანი** (თოკი), + `Arrow` |
| გრძელი მშვილდი | `LongBow` | 2.44 სიგანე | 202 | **რიგიანი**, + `Arrow` |
| არბალეტი | `Crossbow` | 0.92 | 343 | **რიგიანი**, + `Bolt` |
| ისარი / ჭოკი | `Arrow_solo` / `Bolt_solo` | 1.10 / 0.47 | 25 / 30 | |
| კაპარჭები | `Bow_ArrowQuiver`, `Longbow_ArrowQuiver`, `Crossbow_BoltQuiver` | 0.81 / 0.89 / 0.50 | ~200–280 | ზურგზე ან წელზე |
| საბრძოლო ხელთათმანი | `Caestus` | 0.29 | 438 | ხელზე ჩასაცმელი |
| კლანჭი | `Claw` | 0.52 | 257 | ხელზე ჩასაცმელი |

იარაღები Polysplit-ის 2 მ-იან ფიგურებზეა გაზომილი, ჩვენი გმირები კი ≈5%-ით პატარები არიან.
ორხელა ხმალი (2.18 მ) და შუბი (2.93 მ) ზედმეტად დიდად შეიძლება გამოჩნდეს. ჩასმის შემდეგ თვალით შევამოწმოთ, საჭიროების შემთხვევაში ×0.85–0.9.

## 3. როგორ შევიტანოთ თამაშში (გეგმა ახალი სესიისთვის)

**წაიკითხე ჯერ:**
- README: „The maker: YOUR OWN“ და „The heroes on the mannequin…“;
- `ANIMATION_MIGRATION.md` §3 (2. იარაღის დაჭერა ტიპის მიხედვით);
- `vepxis-art/tools/ps_creator.py`: იქ Heroes-ის იარაღები ჯდება `weapon_r` / `shield_l`-ზე, სახელური მუშტში.

**ნაბიჯები:**
1. **FBX → glb.** თითო იარაღი, თითო სტილი (ან ჯერ მხოლოდ Normal): `assets/weapons/<style>/<name>.glb`.
   წინასწარ შეღებილი PNG თითო სტილზე ერთხელ, ტექსტურად. glTF-ში alpha-ს გარეშე.
   რიგიანები (Bow, LongBow, Crossbow, Flail) ძვლებით გადმოვიტანოთ, მშვილდის თოკი `BowModifier`-ს სჭირდება.
2. **კატალოგი:** `scripts/weapon_catalog.gd` (ან `PolysplitLook`-ის „arms“-ის გაფართოება). სახელი, ტიპი და დაჭერის წესი:

   | ტიპი | იარაღები | დაჭერა |
   | --- | --- | --- |
   | `one_hand` | ხმლები, ცული, ჩაქუჩი, გურზი, ხანჯალი, ჯოხი | |
   | `two_hand` | ორხელა, დიდი ცული/ჩაქუჩი, ჰალბერდი | |
   | `polearm` | შუბი, ჰალბერდი, კვერთხი | ტარზე ორ წერტილში |
   | `shield` | ფარები | |
   | `bow`, `crossbow` | მშვილდები, არბალეტი | |
   | `fist` | ხელთათმანი, კლანჭი | |

3. **დაჭერა:** პივოტი უკვე სახელურზეა. ჩვენს `weapon_r`-ზე საჭიროა მხოლოდ ბრუნვა: პირი −Y-დან იმ მიმართულებაზე, რომელსაც ჩვენი ხმალი იყენებს (ps_creator-ის ხმლის მიხედვით). ფარი `shield_l`-ზე, წინამხარზე.
   შუბისა და კვერთხის პივოტი შუაშია: მუშტი პივოტზე, ან დაჭერის წერტილი ცალკე.
4. **YOUR OWN-ის მენიუში** ARMS ჩანართზე ახალი იარაღები და სტილი (Normal / Ornate / Obsidian / Bone).
5. **დარტყმის ზონა:** `SkinnedRig._reach()` პირს ხელში ზომავს, ამიტომ გრძელი იარაღი თავისით შორს მოჭრის. შეამოწმე `grip_test`-ით (იარაღი ხელშია, პირი ტანში არ შედის).
6. **ტესტები:** `maker_test`, `grip_test`, `swordsman_test`, `skinned_rig_test`, `smoke_test`. ეკრანის სურათები: თითო ტიპი ხელში.
7. **მონსტრებსაც** შეუძლიათ ამ იარაღის აღება: Polysplit-ის Biped Creatures-ს იგივე ჩონჩხი აქვს, `R_equip_joint`-ით (`CREATURES_PACK.md` §3).

## 4. ხაფანგები

- Blender-ის FBX იმპორტში დამალული ობიექტების `matrix_world` ძველია, სანამ არ გამოჩნდება (`hide_set(False)` + `view_layer.update()`). ეს Heroes-იდანაა ცნობილი.
- `*_Set.fbx`-ში იარაღი და ქარქაში ერთად არის, მშობლად EMPTY აქვთ. ქარქაში ცალკე მეშად გამოიყოფა.
- 3 ფაილს (`Axe`, `Spear`, `Wand`) მასალად `lambert1` აქვს.
