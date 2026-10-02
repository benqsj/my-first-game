# გმირები ახალ ჩონჩხზე და ახალი ანიმაციები — გეგმა

ეს დოკუმენტი ახალი სესიისთვისაა. დაწერილია 2026-10-02-ს, მას შემდეგ, რაც
მომხმარებელმა ლაბორატორიაში (`scenes/tools/anim_lab.tscn`) ანიმაციები აირჩია.

## 1. რა გვინდა

ხუთივე გმირი (ტარიელი, ავთანდილი, ასასინი, ჯადოქარი, ვარიორი) უნდა
გადავიდეს **UAL2-ის mannequin-ის ჩონჩხზე** (UE-ის სტანდარტი: ხერხემალში 3
ძვალი, ყველა თითი) და იბრძოლოს **მომხმარებლის მიერ არჩეული ანიმაციებით**.

ახლა ასე ხდება: Mixamo → tariel_rig (36 ძვალი, თითების გარეშე) → Polysplit-ის
ფიგურა. ორი გადატანაა. შედეგად:
- სირბილისას ფიგურა დეფორმირდება;
- ზოგ გმირს ხმალი ხელში არ უჭირავს, ზოგს ტანში აქვს გაყრილი;
- მშვილდის თოკი გაწელილია;
- ასასინს დანა ხელიდან გადის.

## 2. რა გვაქვს უკვე (გადამოწმებულია)

| რა | სად |
| --- | --- |
| mannequin + UAL2-ის 134 კლიპი (როგორც ნაყიდი) | `assets/anim/lab/ual2_mannequin.glb` (Godot სახელებს `_Loop`-ს აჭრის) |
| Kevin-ის 119 კლიპი mannequin-ზე | `assets/anim/lab/kevin_lib.res` (AnimationLibrary, `KV_*`, ბილიკები `Armature/Skeleton3D:<bone>`) |
| Polysplit-ის ფიგურა mannequin-ის კიდურებზე | `assets/polysplit/mannequin_m.glb` (`ps_creator.py mannequin m`) |
| მომხმარებლის არჩევანი, 45 მოძრაობა | `assets/anim/lab/picks.json` (`column` = მთავარი, `also` = ასევე შესანახი, შემთხვევით) |
| არჩევანის ცხრილი სიტყვებით | README: „The user's picks (2026-10-02)“ |
| ლაბორატორია | `scripts/anim_lab.gd`, ღილაკები README-ში |
| Kevin-ის retarget-ი (Godot) | `vepxis-art/tools/kv_godot.gd`, `fbx2glb.gd`; FBX→glb: `vepxis-art/kevin_melee/glb/` |

## 3. რიგი

1. **ფარი.** mannequin-ის ფიგურაზე ფარი წინამხარზე სწორად დაჯდეს
   (`ps_creator.py`, shield-ის ბლოკი): გარეთ იყურებოდეს, მკლავზე ედოს. Kevin-ის
   `BlockShield01_Loop`-ითა და `AttackShield01`-ით შეამოწმე.
2. **იარაღის დაჭერა ტიპის მიხედვით:** ხმალი, ორხელა, დანა, კვერთხი, ფარი,
   მშვილდი. ახლა ყველა იარაღი პაკეტის ბუნებრივი ადგილით ზის მაჯის ძვალზე.
   Kevin-ს `B-handProp` აქვს (იარაღის წერტილი), UAL2-ს `hand_r`.
3. **ტესტი:** ყოველ არჩეულ კლიპს კადრ-კადრ ჩაივლის და ამოწმებს, რომ:
   - იარაღი ხელშია (სახელურიდან მუშტამდე < რამდენიმე სმ);
   - პირი ტანის კაფსულაში რამდენად შედის.
   ცუდი კლიპები სახელით ჩამოწერე.
4. **ნაკრებები (movesets) იარაღის ტიპით** `picks.json`-იდან: სლოტი → კლიპები
   (მთავარი + `also`, შემთხვევით). „NOW (MIXAMO)“ არჩევანი (dodge, jump, climb)
   გმირის ახლანდელ კლიპს ნიშნავს, რომელიც mannequin-ზეც უნდა დარჩეს.
5. **გმირები mannequin-ზე.** SkinnedRig-ი mannequin-ის ჩონჩხს იღებს
   (`ual2_mannequin.glb`, მეშის გარეშე) + Kevin-ისა და UAL2-ის ბიბლიოთეკები.
   - `clips` / `flurry` / `heavy` ცხრილები ნაკრებიდან.
   - `cut_window`, `trail_window`, `flurry_part`: ახალ კლიპებზე თავიდან
     გასაზომია (Blender-ში ან Godot-ში, პირის სიჩქარით, როგორც ძველებზე).
   - root motion: Kevin in-place-ია, UAL2-იც.
   - mannequin-ზე ფიგურა: `mannequin_m.glb` თითო გმირს; ქალისთვის
     `ps_creator.py mannequin f`.
   - ძველი გმირის მოდელები (AS HE WAS და სხვ.) Mixamo-ზე რჩება, სანამ
     მომხმარებელი სხვას არ იტყვის. ჰკითხე.
6. **ჯადოქარი:** ხმალი მარჯვენაში. ჯადოს კლიპი არცერთ პაკეტს არ აქვს, ამიტომ
   ტარიელის `SS_Spell_Casting` mannequin-ზე გადაიტანე მხოლოდ ზედა ტანზე.
7. **მშვილდის თოკი:** UAL2-ის მშვილდზე თოკი `draw_r`-ს (მარჯვენა ხელს) უნდა
   მიჰყვეს. BowModifier mannequin-ის ძვლებზე.
8. ტესტები (`maker_test`, `figures_test`, `skinned_rig_test`, `heroes_test`,
   `archer_test`, `fighter_test`, `combat_test`, `smoke_test`), README/NOTES,
   commit, **ვიდეო თამაშიდან** (თითო გმირი: სირბილი, დარტყმები, ბლოკი).

## 4. ხაფანგები (უკვე ნანახი)

- Blender-ის FBX იმპორტერი Kevin-ს წაქცეულს შემოიტანს (rest -Y-ზე, ანიმაცია
  სანტიმეტრებში). ამიტომ retarget Godot-შია (`kv_godot.gd`).
- დამალული FBX ობიექტები: `matrix_world` ძველია, სანამ არ გამოჩნდება და
  `view_layer.update()` არ მოხდება.
- `device_commit_files` staged path-ით ქეშავს: ყოველი ახალი ვერსია ახალი
  ბილიკიდან გააგზავნე და md5-ით შეამოწმე.
- device_bash-ს წაშლა არ შეუძლია: git-ის lock/tmp ფაილები Blender-ის
  python-ით წაშალე, ან git-ი subprocess-ით გაუშვი.
- settings.cfg-ში ძველი look-ის ინდექსები: `set_face` საზღვარს გარეთ
  ინდექსს 0-ზე აბრუნებს.
- heroes_test-ის 4 ჩავარდნა და smoke_test-ის physics tick ძველია (HEAD-ზეც
  ასეა).

## 5. დამატებით (2026-10-02, მომხმარებლის კითხვიდან)

- Kevin-ის ნაყიდ პაკეტში სადემონსტრაციო იარაღებიცაა:
  `kevin_melee/pkg/Assets/Kevin Iglesias/Human Animations/Unity Demo Scenes/Human Melee Animations/Models/`:
  Human_Sword, Human_Shield, Human_Dagger, Human_Greatsword, **Human_Polearm (შუბი)**,
  **Human_Warhammer (ჩაქუჩი)**. მომხმარებელს render-ით აჩვენე. თუ მოეწონება, Polysplit-ის
  ფერების ტექსტურაზე გადაიყვანე და შუბი/ჩაქუჩი იარაღებს დაამატე.
  ისინი ზუსტად Kevin-ის კლიპებისთვისაა გაკეთებული, ამიტომ ხელში ზუსტად დაჯდება
  (Kevin-ის `B-handProp`).
- Kevin Iglesias ტანსაცმელს არ ყიდის (მხოლოდ ანიმაციები და უფასო Human Character Dummy).
  ტანსაცმლისთვის Polysplit-ის სერიის სხვა პაკეტები გადაამოწმე.
