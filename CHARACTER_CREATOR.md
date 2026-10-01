# გმირის აწყობა მენიუში (Polysplit Heroes) — გეგმა

ეს დოკუმენტი ახალი სესიისთვისაა. აქ წერია, რა გვინდა, რა გვაქვს უკვე და რა
თანმიმდევრობით გავაკეთოთ. ჯერ მხოლოდ **მენიუ და გარეგნობაა** (ნაწილი 1–6).
ანიმაციები მოგვიანებით მოვა (ნაწილი 7). ახლა მათ არ ვეხებით.

დაწერილია 2026-10-02-ს. ყველა რიცხვი და ფაილის სახელი ამ დღეს ფაილებიდან
არის გადამოწმებული.

---

## 1. რა გვინდა

მენიუში, გმირის არჩევისას, მოთამაშეს გმირის **სრულად აწყობა** შეეძლოს.
ჯერ კლასი ირჩევა, მერე დანარჩენი:

1. **გმირი**: ჩვენი ხუთი გმირიდან ერთ-ერთი (ტარიელი, ავთანდილი, ასასინი,
   ჯადოქარი, ვარიორი), როგორც ახლაა.
2. **კლასი**: Polysplit-ის კლასი, რომელიც ამ გმირს ერგება (იხ. §3.2). კლასი
   ტანსაცმლის, თავსაბურავისა და იარაღის საწყის ნაკრებს ადგენს.
3. **სქესი** (თუ გინდა; პაკეტს ქალის ვერსიაც აქვს, იხ. §6, ღია კითხვები).
4. **სახე**: თვალები, წარბები, პირი, წვერი (ან წვერის გარეშე).
5. **თმა**.
6. **ტანსაცმელი**: ზედა, ქვედა, მოსასხამი/შარფი და სხვა. სხვა კლასის
   ტანსაცმლის შერევაც შეიძლება.
7. **თავსაბურავი**: კლასისა, ან პაკეტის ცალკე თავსაბურავებიდან ერთ-ერთი,
   ან არაფერი.
8. **ფერები**: კანის/თმის ფერი (body 1–8) და ტანსაცმლის ფერი (objects 1–14).
9. **იარაღი**: პაკეტის იარაღებიდან, რაც გმირის ბრძოლის სტილს ერგება.
   **ჯადოქარს ხმალი უნდა ეჭიროს**, ხელებით ბრძოლა არ გვინდა.

არჩეული ყველაფერი ინახება (როგორც ახლა face/hair) და თამაშში ზუსტად ის ჩანს.
მულტიპლეერშიც ეგზავნება სხვებს.

---

## 2. რა გვაქვს უკვე

### ფაილები
| რა | სად |
| --- | --- |
| Polysplit-ის პაკეტი (ყიდული, Unity EULA) | `~/Library/Unity/Asset Store-5.x/Polysplit Games/.../Low-Poly Medieval Fantasy Heroes - Basic Pack.unitypackage` |
| ამოლაგებული | `vepxis-art/polysplit/pkg/Assets/PolysplitGames/LowPolyMedievalFantasyHeroes/` |
| guid → ფაილი | `vepxis-art/polysplit/guids.json` |
| ერთი look-ის აწყობა (Swordsman) | `vepxis-art/tools/ps_build.py` → `vepxis/assets/tariel_polysplit/tariel_polysplit.glb` |
| თამაშში | ტარიელის 10-ე სახე **THE SWORDSMAN** (`SkinnedRig.figures.polysplit`, `polysplit_map()`) |

### როგორ მუშაობს ფიგურა თამაშში
- Polysplit-ის პერსონაჟი **თავის ჩონჩხზე** რჩება (98 ძვალი). `FigureFollower`
  (`scripts/figure_follower.gd`) ყოველ კადრში გმირის ჩონჩხს მიჰყვება: ყოველი
  ძვალი ზუსტად ისე ბრუნდება, როგორც გმირის შესაბამისი ძვალი თავისი rest-იდან.
  ამიტომ ანიმაციები გმირის rig-ზე რჩება და ფიგურა უბრალოდ მიჰყვება.
- `ps_build.py` ფიგურის rest-ს ტარიელის კიდურების მიმართულებებზე აბრუნებს,
  ხელებს მუშტად კრავს, ამატებს `weapon_r` და `shield_l` ძვლებს და იარაღს
  მუშტში სვამს. იგივე გზაა, რაც `sk_build.py`-ში (Sidekick) და
  `bl_blink.py`-ში (Blink).
- ასასინისა და ავთანდილისთვის `fig_hero.py`-ში უკვე არის თავისი ძვლები:
  `weapon_l` და `bow_l`/`draw_r`.

### ახლანდელი მენიუ
- `scripts/main_menu.gd`: გმირის არჩევის გვერდზე სამი სვეტია: სია, სცენა
  (`CharacterPortrait`, ის მოდელი, რასაც თამაში იყენებს) და dossier.
- სცენის ქვეშ ორი picker-ია: **LOOK** (`faces`) და **HAIR**. ორივე ისრებით
  გადაირთვება (`_picker()`, `_step()`) და ინახება გმირზე
  (`_game.face(id)` / `_game.hair(id)`, settings.cfg).
- ახალი არჩევანი იმავე სქემით უნდა დაემატოს: picker-ი თითო კატეგორიაზე,
  ინახება გმირზე, rig-ს ესმის.

---

## 3. Polysplit-ის პაკეტში რა არის (გადამოწმებულია)

### 3.1 საერთო
- **ერთი ჩონჩხი ყველაფერზე** (99 ძვალი, `rootSkeleton`): `pelvis_joint`,
  `waist_joint`, `chest_joint`, `neck_joint`, `head_joint`, `L_/R_clavicle,
  shoulder, elbow, wrist`, ხუთი თითი, `L_/R_equip_joint` (იარაღის წერტილი),
  `bowJoint`/`stringJoint`, თმის, მოსასხამისა და კალთის ჯაჭვები.
- T-პოზაა, `-Y`-ისკენ იყურება, ~6%-ით მაღალია ტარიელზე.
- FBX-ები სანტიმეტრებშია (scale 0.01, Rx90). იმპორტის შემდეგ transform_apply.
- **ტექსტურები:** ორი მასალაა, `genericRGBMat_Body` და `genericRGBMat_Objects`.
  ფერი ტექსტურაშია:
  - `BodyPreColors/medievalTexture_bodyColor1..8.png` (კანი, თმა, თვალები);
  - `ObjectPreColors/medievalTexture_objectColor1..14.png` (ტანსაცმელი,
    იარაღი).
  ფერის შეცვლა = ტექსტურის შეცვლა, UV იგივე რჩება. იაფია, მესი არ იცვლება.
  (`genericRGB_medievalTexture.png` + `RGBRecolor_*` მასალები Unity-ის
  shader-ს სჭირდება. თუ 22 PNG-ზე მეტი ფერი გინდა, Godot-ში მსგავსი
  shader უნდა დაიწეროს. ჯერ არ გვჭირდება.)

### 3.2 კლასები (`BasicHeroes/M_<Class>.fbx`, `F_<Class>.fbx`)
თითო ფაილში არის **მთელი საბაზისო სხეული** (ყველა თმა, თვალი, წარბი, პირი,
წვერი) და კლასის ტანსაცმელი:

| კლასი (კაცი) | ნაწილები | რომელ ჩვენს გმირს ერგება |
| --- | --- | --- |
| Swordsman | Top, Bottom, SkullCap, SkullCap_ChainCoif, Sword, SwordScabbard | ტარიელი |
| Fighter | Top, Bottom, Headband, Sword, SwordScabbard | ტარიელი |
| Knight | Top, Bottom, Pauldrons, NeckScarf, GreatHelm, Greatsword, GreatswordScabbard, SwordSheathed | ვარიორი (ორხელა) / ტარიელი |
| Archer | ⚠ Blender-ში არ იხსნება (§5) | ავთანდილი |
| Hunter | Top, Bottom, FeltedHat, Bow, Arrow, ArrowQuiver, Dagger_sheathed_R | ავთანდილი |
| Rogue | Top, Bottom, Eyepatch, Dagger_L, Dagger_R, DaggerScabbard_L/R | ასასინი |
| Mage | Top, Bottom, Headwear, SlingBag, Staff | ჯადოქარი |
| Sorcerer | Top, Bottom, Cloak, Shoes, BishopHat, Staff | ჯადოქარი |
| Warlock | Top, Bottom, Cape, Hood, Staff | ჯადოქარი |

ქალის კლასებია Archer, Fighter, Hunter, Knight (ArmetHelmet + Visor, Skirt,
Dagger), Mage (Cape, Scarf), Rogue (FaceMask, NeckWrap), Sorcerer (Shawl,
Circlet), Swordsman (KettleHat) და Witch (Cape, Choker). `F_*`-ებიდან ყველა
იხსნება.

- **სახე:** `M_Head` (ერთი თავი) + `M_eyes0..4`, `M_eyebrows0..4`,
  `M_mouth0..4` (decal-ები, §5) + `facialHair_1..8` (წვერი/ულვაში).
- **თმა:** `M_hair_1..14`. თითოს აქვს `b` ვარიანტი (`M_hair_Nb`, ზოგს
  `_Top`/`_Bangs`) თავსაბურავის ქვეშ (ჯგუფი `Hair_forHeadwear`).
  **თავსაბურავისას b ვარიანტი ჩანს**, მის გარეშე ჩვეულებრივი.
- **სხეული:** `M_TopBody`, `M_BottomBody` (ტანსაცმლის ქვეშ ზოგჯერ
  იმალება). ტანსაცმლის `Top`-ს თავისი კანის ნაწილი აქვს, ამიტომ Top
  ჩაცმისას `M_TopBody` უნდა დაიმალოს (Swordsman-ში ასეა).
- ⚠ ერთ ფაილში ზოგი ვარიანტი სხვა world-scale-ით იმპორტდება (0.01-ის
  ნაცვლად 1). `transform_apply` ყველაფერს ასწორებს, მაგრამ ზომა
  render-ით შეამოწმე.

### 3.3 ცალკე ნაწილები
- **თავსაბურავი** (`BasicHeadwear/`, 24 ცალი): ArmetHelmet_M/F, Beret,
  BishopHat, BycocketHat, Circlet_M/F, Eyepatch_L/R, FaceMask_M/F, FeltedHat,
  GreatHelm, Headband, Hood, KettleHat_M/F, LeatherCoif_M/F, MageHat_A/B,
  SkullCap, TyroleanHat, WitchHat. GreatHelm-სა და Hood-ს **ჩონჩხი არ აქვთ**
  (0 ძვალი; დანარჩენებიც, სავარაუდოდ, ასეა): `head_joint`-ზე უნდა მიება.
- **იარაღი** (`BasicWeapons/`): SwordBasic_A/B (+ქარქაში), GreatswordBasic
  (+ქარქაში), DaggerBasic (+ქარქაში), ShieldBasic, StaffBasic_A/B, BowBasic
  (2 ძვალი, ლარისთვის), ArrowBasic, ArrowQuiverBasic. ჩონჩხის გარეშეა:
  იარაღის ძვალზე (`weapon_r`/`weapon_l`/`shield_l`/`bow_l`) უნდა დაჯდეს.
- `Heroes_PrePosed/*.fbx`: გაყინული პოზები, სტატიკური მეში. თამაშში არ
  გვჭირდება.
- `BaseCharacters/StillCharacterPoses/HeroPoses.fbx`: პოზები, მეშის გარეშე.

---

## 4. როგორ გავაკეთოთ (ტექნიკური გზა)

### 4.1 ერთი glb ყველა ნაწილით (Blender, `tools/ps_build.py` გაფართოებული)
- ერთი ფაილი სქესზე: `assets/polysplit/ps_male.glb`, `ps_female.glb`.
  შიგნით ერთი ჩონჩხია (rest ტარიელზე გასწორებული, მუშტები, `weapon_r`,
  `weapon_l`, `shield_l`, `bow_l`, `draw_r` ძვლები). **ყოველი ნაწილი
  ცალკე მეშია** თავისი სახელით (`ps_hair_3`, `ps_hair_3b`, `ps_beard_2`,
  `ps_eyes_1`, `ps_top_swordsman`, `ps_hat_greathelm`, `ps_w_sword_a`...).
- ყველა კლასის FBX-ს ერთხელ შემოიტანს. ერთნაირ ნაწილებს (თავი, თმა,
  თვალები...) ერთხელ აიღებს, კლასის ტანსაცმელს ყველა კლასიდან.
- თავსაბურავები `head_joint`-ზე, იარაღები იარაღის ძვლებზე, rigid
  (weight 1). იარაღი ტარიელის/ავთანდილის/ასასინის იარაღის ღერძებზე
  ჯდება, როგორც ახლა Swordsman-ის ხმალი (`axes()`/`frame()`).
- მასალა ორია (body, objects), ფერის ტექსტურები Godot-ში იცვლება.
- გმირებს ერთი ფაილი ეყოფა: იარაღის ძვლები ყველასთვის ერთ ჩონჩხზეა.
  `fig_hero.py`-ს გმირის ძვლებს დაემატება. თუ ერთი ჩონჩხი ყველა გმირს
  ვერ მოერგება (მაგ. ასასინის მარცხენა ხელის ოფსეტი), ცალკე ფაილი გმირზე.
- **ზომა:** კლასი ~3k სამკუთხედია, ყველა ნაწილი ერთად ბევრად მეტი.
  Godot-ში დამალული მეში არ იხატება, ამიტომ თამაშში ამას მნიშვნელობა
  არ აქვს, ფაილის ზომა კი შეამოწმე.

### 4.2 Godot: `PolysplitLook` (ახალი კლასი)
- ერთი Dictionary აღწერს look-ს:
  `{gender, class, eyes, brows, mouth, beard, hair, top, bottom, extras[],
  hat, body_color, object_color, weapon, offhand}`.
- `apply(figure_node, look)`: ყველა `ps_*` მეშს მალავს/აჩენს, თმაზე b
  ვარიანტს ირჩევს, თუ ქუდია, `M_TopBody`-ს მალავს, თუ Top ჩაცმულია, და
  ტექსტურებს ცვლის (`material_override` ან surface material,
  `albedo_texture`).
- გმირის rig-ში (`SkinnedRig.figures`) Polysplit ფიგურა ერთხელ ჩაიტვირთება.
  look იცვლება მეშების ჩართვით და ფიგურის ხელახალი ჩატვირთვა არ ხდება.
- იარაღი: `weapon` ირჩევს, რომელი `ps_w_*` ჩანს. blade_base/tip
  (დარტყმის ხაზი) არჩეული იარაღის სიგრძეზე უნდა გადაითვალოს. ახლა ის
  ხმალზეა მიბმული, იხ. `_figure_mount` skinned_rig.gd-ში.
- **ჯადოქარი ხმლით:** ჯადოქრის კლასებიდან Staff მოიხსნება (ან ზურგზე
  გადავა) და `weapon_r`-ზე ხმალი ჯდება. ჯადოს კლიპები მერე ზედა ტანზე
  მოვა (§7).

### 4.3 მენიუ
- გმირის არჩევის გვერდზე, სცენის ქვეშ, ახალი picker-ები, ახლანდელი
  `_picker()`-ის სტილით: **CLASS, BODY, EYES, BROWS, MOUTH, BEARD, HAIR,
  TOP, BOTTOM, EXTRA, HAT, SKIN COLOUR, CLOTH COLOUR, WEAPON**.
- ბევრია. ჯობია ჯგუფებად (ჩანართები ან გვერდები): **CLASS → FACE (თვალი,
  წარბი, პირი, წვერი, თმა, კანის ფერი) → GEAR (ტანსაცმელი, ქუდი, ფერი)
  → WEAPON**. კლასის შეცვლა GEAR-სა და WEAPON-ს კლასის ნაგულისხმევზე
  აბრუნებს, FACE-ს არ ეხება.
- კამერა: FACE-ზე `Frame.FACE` (`CharacterPortrait`-ს უკვე აქვს), დანარჩენზე
  `Frame.FULL`.
- ინახება გმირზე, როგორც face/hair: `settings.cfg`-ში look Dictionary.
  მულტიპლეერში announce-ს ემატება (`net.gd`).
- ერთი picker = ისრები ← → და სახელი/ნომერი. ფერზე ფერის ნიმუშებიც
  შეიძლება.

---

## 5. ხაფანგები (უკვე ნანახი)

- **Blender-ის FBX იმპორტერი** `M_Archer.fbx`-სა და
  `All-in-One_SeparateGenders/BasicHero_M.fbx`-ზე ვარდება:
  `KeyError: rootSkeleton` (`import_fbx.py`, `link_hierarchy`). ქალის
  ფაილები და კაცის სხვა კლასები იხსნება. რისი ცდა შეიძლება:
  `automatic_bone_orientation`, `ignore_leaf_bones`,
  `use_custom_props=False` და სხვა პარამეტრები; Unity-ში (`~/UnityBlink`)
  პაკეტის იმპორტი და FBX Exporter-ით ხელახლა გატანა; ან Archer-ის
  ნაწილების (Bow, Quiver, Cape, BycocketHat) აღება ქალის ფაილიდან, თუ
  კაცზე ჯდება (სხეულის ფორმა განსხვავდება, ტანსაცმელი არ მოერგება).
- **სახის decal-ები** (თვალი, წარბი, პირი) ალფიან ოთხკუთხედებზეა.
  მასალის Alpha → Math "GREATER_THAN 0.5" → BSDF Alpha, მაშინ glTF
  `alphaMode: MASK`-ს წერს. თუ არა, Godot-ში სახე წითელ-თეთრი ბლოკია.
- **UV map-ების სახელები** ნაწილებს შორის განსხვავდება. join-მდე თითო
  ნაწილს ერთი ფენა დაუტოვე `UVMap` სახელით. აქ ნაწილებს არ ვაერთებთ,
  მაგრამ სახელები მაინც გაასწორე.
- **ინტერაქტიულ Blender-ს არ შეეხო.** მომხმარებლის Blender-ში შეუნახავი
  სცენაა (~470 ობიექტი). აწყობა `blender -b --factory-startup -P ...`-ით
  ცალკე პროცესში, MCP-დან `subprocess`-ით. 60 წამზე გრძელი
  `Popen` + ლოგი.
- MCP ზარი 60 წამში წყდება. `.unitypackage`-ის ამოლაგება ფონზე გაუშვი.
- git-ის lock/tmp ფაილები: device_bash-ს წაშლის უფლება არ აქვს. git-ის
  ბრძანებები Blender-ის `subprocess`-ით გაუშვი Mac-ზე, ან წაშლის ნებართვა
  ითხოვე.

---

## 6. სამუშაოს რიგი და ღია კითხვები

> **2026-10-02: ნაწილები 1–6 გაკეთდა** (README, „The maker: YOUR OWN“).
> ღია კითხვებზე პასუხები: ქალის ვერსია ყველა გმირს აქვს; ძველი look-ები
> რჩება, YOUR OWN მათ შემდეგ დაემატა (THE SWORDSMAN-ის ადგილზე); ყველა
> კლასი ყველა გმირისთვისაა, საკუთარი პირველია; პაკეტის 8 + 14 PNG ფერი
> საკმარისია. იარაღის შეცვლა ჯერ მხოლოდ გარეგნობას ცვლის (სტილი §7-ში).
> Archer-ი Godot-ის fbx reader-ით შემოვიდა (§5).

### რიგი
1. `ps_build.py` → ყველა ნაწილი ერთ glb-ში (ჯერ კაცი). Blender-ის
   render-ებით შეამოწმე: თმა+ქუდი, Top+TopBody, ყველა იარაღი ხელში.
2. Archer-ის იმპორტის პრობლემა (§5).
3. `PolysplitLook` + rig-ში ჩართვა. ტესტი: ყოველი კატეგორიის ყოველი
   ვარიანტი ჩნდება, სხვა იმალება, ხელი/ფეხი rig-ს 0.35 მ-ში ემთხვევა.
4. მენიუს picker-ები + შენახვა + მულტიპლეერი.
5. ქალის ვერსია (თუ გვინდა).
6. ტესტები: `menu_test`, `skinned_rig_test`, `figures_test`, `heroes_test`,
   `multiplayer_test`, `smoke_test`. სქრინშოტები მენიუდან, თითო
   კლასზე და რამდენიმე აწყობაზე.

### ღია კითხვები (მომხმარებელს ჰკითხე დასაწყისში)
- **ქალის ვერსია:** გვინდა? ყველა გმირისთვის?
- **ძველი სახეები:** ტარიელის 10 look (AS HE WAS, Blink, Sidekick...)
  დარჩეს Polysplit-ის აწყობის გვერდით, თუ Polysplit ჩაანაცვლებს?
  (ART-ის მიმართულება low-poly-ა, `ASSET_WISHLIST.md`.)
- **კლასები გმირებზე:** §3.2-ის ცხრილი შეთავაზებაა. შეუძლია თუ არა
  ნებისმიერ გმირს ნებისმიერი კლასის ჩაცმა, თუ მხოლოდ თავისი?
- **იარაღი და ბრძოლა:** იარაღის შეცვლა ბრძოლის სტილსაც ცვლის (ორხელა =
  ვარიორის კლიპები), თუ მხოლოდ სახეს? ჯერ მხოლოდ სახე, სტილი §7-ში.
- **მცირე ფერები:** 8 + 14 PNG საკმარისია, თუ ჩვენი shader და თავისუფალი
  ფერები გვინდა?

---

## 7. მერე: ანიმაციები (ახლა არ ვაკეთებთ)

ორივე ფასიანი პაკეტი ნაყიდი და ჩამოტვირთულია.

| პაკეტი | სად | რა არის |
| --- | --- | --- |
| Kevin Iglesias – Human Melee Animations (Unity EULA) | `~/Library/Unity/Asset Store-5.x/Kevin Iglesias/Animation/Human Melee Animations.unitypackage`, ამოლაგებული `vepxis-art/kevin_melee/pkg/` | 310 FBX (კაცი + ქალი). კაცის, root motion-ის გარეშე: 1H 21, 2H 9, Polearm 9, Shield 4, Unarmed 10, Combat 11, Unsheathe 12, Walk 8, Run 8, Sprint 5, StrafeWalk 6, StrafeRun 6, Turn 4, Idles 2. თითოს `RootMotion/` ვერსიაც აქვს. |
| Quaternius – UAL 2 Source (CC0) | ჩამოტვირთული: `vepxis-art/human-males-animation/human-male-animations` (zip, გაფართოების გარეშე); ამოღებული: `vepxis-art/ual2_source/` (`Unreal-Godot/UAL2.glb`, `UAL2_RM.glb`, `UAL2.blend`) | 134 კლიპი: Bow_* (Notch, Aim Up/Neutral/Down, Shoot, RapidShoot), Sword_Light/Regular/Heavy (A–D, Rec, Combo), Sword_Aerial_*, GroundPound, UpperCut, Block, Dash, Walk 8 მიმართულებით, ClimbUp 1–2 მ, WallRun, SafetyVault, DoubleJump, NinjaJump, Slide... **ჯადო და ჩვეულებრივი სირბილი არ აქვს.** |

რა უნდა გაკეთდეს:
1. `vepxis-art/tools/kv_retarget.py`-ის `CLIPS`-ში ორივე ფასიანი პაკეტის
   კლიპები (Kevin-ის კაცის in-place ყველა, UAL2-ის ბრძოლა, მოძრაობა,
   მშვილდი). UAL2 Source-ის წყარო `ual2_source/Unreal-Godot/UAL2.glb`.
   სკრიპტი უკვე მუშაობს (უფასოებზე 22 კლიპი გადავიდა), მხოლოდ სია
   იზრდება.
2. **შედარება** ისევე, როგორც პირველად: სამი ფიგურა, Kevin | UAL2 |
   ახლანდელი Mixamo, თითო გმირის სტილზე (ტარიელი ხმალი+ფარი, ვარიორი
   ორხელა, ასასინი ორი დანა, ავთანდილი მშვილდი, ჯადოქარი ხმალი + ჯადო).
   სცენა: `vepxis-art/polysplit/cmp.gd` (გაუშვი `_shots_tmp/`-დან,
   `--write-movie`), ვიდეოს აწყობა: `vepxis-art/polysplit/_enc.py`.
3. მომხმარებელი ირჩევს, რომელი კლიპი რომელ გმირს რომელ მოქმედებაზე
   (`clips`, `flurry`, `heavy` ცხრილები rig-ებში).
4. ჯადოქარი ხმლით: ჯადოს კლიპი (Kevin Spellcasting არ გვაქვს; ტარიელის
   ბიბლიოთეკაში არის `SS_Spell_Casting`, `SS_Spell_Casting_2`) მხოლოდ
   ზედა ტანზე/მარცხენა ხელზე, ხმალი მარჯვენაში რჩება.

ახლანდელი შედარების ვიდეო (უფასოებით): `vepxis-art/polysplit/melee_compare.mp4`.
