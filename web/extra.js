// Hand-written romanizations the neural romanizer gets wrong, plus the
// casual spellings Thais use in chat. Format: [thai, romanization].
// Add your own lines here — no rebuild needed.
window.THAI_EXTRA = [
  ["อร่อย", "aroi"], ["อร่อย", "aroy"],
  ["ไหม", "mai"], ["มั้ย", "mai"], ["ไหม", "mhai"],
  ["ครับ", "krub"], ["ครับ", "khrub"], ["คับ", "kub"],
  ["ค่ะ", "ka"], ["ค่ะ", "kah"], ["คะ", "ka"], ["จ้ะ", "ja"], ["จ้า", "jaa"],
  ["ขอบคุณ", "kobkun"], ["ขอบคุณครับ", "khopkhunkhrap"], ["ขอบคุณค่ะ", "khopkhunkha"],
  ["สวัสดี", "sawasdee"], ["สวัสดีครับ", "sawatdikhrap"], ["สวัสดีค่ะ", "sawatdikha"],
  ["เท่าไหร่", "taorai"], ["เท่าไร", "thaorai"],
  ["เป็น", "ben"], ["อยู่", "yu"], ["อยาก", "yak"], ["อย่า", "ya"], ["อย่าง", "yang"],
  ["หนึ่ง", "nueng"], ["สอง", "song"], ["สาม", "sam"], ["สี่", "si"], ["ห้า", "ha"],
  ["หก", "hok"], ["เจ็ด", "chet"], ["แปด", "paet"], ["เก้า", "kao"], ["สิบ", "sip"],
  ["หรือ", "rue"], ["หรือ", "rur"], ["หรอ", "ror"], ["เหรอ", "ror"],
  ["ใช่", "chai"], ["ไม่ใช่", "maichai"], ["ได้", "dai"], ["ไม่ได้", "maidai"],
  ["ที่ไหน", "tinai"], ["อะไร", "arai"], ["ทำไม", "tummai"], ["ยังไง", "yangngai"],
  ["เมื่อไหร่", "muearai"], ["ใคร", "krai"], ["นี่", "nee"], ["นั่น", "nan"],
  ["เพื่อน", "puen"], ["แฟน", "fan"], ["ที่รัก", "tirak"], ["คิดถึง", "kidtueng"],
  ["คิดถึง", "kittueng"], ["รักนะ", "rakna"], ["ฝันดี", "fandee"],
  ["เลย", "loei"], ["เลย", "loey"], ["จริง", "jing"], ["จริงๆ", "jingjing"],
  ["เสร็จ", "set"], ["เสร็จ", "sed"], ["สนุก", "sanook"], ["สบายดี", "sabaidee"],
  ["สบายดีไหม", "sabaideemai"], ["ไปไหน", "painai"], ["กินข้าว", "kinkhao"],
  ["กินข้าวยัง", "kinkhaoyang"], ["หิว", "hiw"], ["ง่วง", "nguang"], ["นอน", "non"],
  ["โอเค", "ok"], ["โอเค", "okay"], ["ขอโทษ", "kotot"], ["ไม่เป็นไร", "maipenrai"],
  ["เก่ง", "keng"], ["สวย", "suay"], ["หล่อ", "lor"], ["น่ารัก", "naruk"],
  ["คอมพิวเตอร์", "computer"], ["โทรศัพท์", "torasap"], ["มือถือ", "muetue"],
  ["ภาษาไทย", "pasathai"], ["ภาษาอังกฤษ", "pasaangkrit"], ["กรุงเทพ", "bangkok"],
  ["ประเทศไทย", "thailand"], ["ทะเล", "talay"], ["เมื่อวาน", "mueawan"], ["เมื่อวาน", "muawan"], ["ร้านอาหาร", "ranahan"], ["โรงพยาบาล", "rongpayaban"],
];

// ---- Chat particles and casual spellings --------------------------------
window.THAI_EXTRA.push(
  ["นะคะ", "naka"], ["นะครับ", "nakrap"], ["นะครับ", "nakub"], ["ครับผม", "krappom"], ["ค่า", "kaa"],
  ["คร้าบ", "kraab"], ["จ้า", "ja"], ["จ้ะ", "ja"], ["จ๊ะ", "ja"], ["เนอะ", "noe"], ["เนอะ", "ner"],
  ["อ่ะ", "a"], ["อะ", "a"], ["ป่ะ", "pa"], ["ปะ", "pa"], ["เปล่า", "plao"], ["เปล่า", "plaw"],
  ["ไง", "ngai"], ["เหรอ", "roe"], ["เหรอ", "rer"], ["หรอ", "ror"], ["แหละ", "lae"], ["ล่ะ", "la"],
  ["สิ", "si"], ["ซิ", "si"], ["จัง", "jang"], ["เว้ย", "woei"], ["ว่ะ", "wa"], ["มั้ย", "mai"],
  ["ไม่ไหว", "maiwai"], ["เป็นไง", "penngai"], ["เป็นไงบ้าง", "penngaibang"], ["ทำอะไรอยู่", "tamaraiyu"],
  ["อยู่ไหน", "yunai"], ["ว่าง", "wang"], ["ว่างไหม", "wangmai"], ["เดี๋ยว", "diao"], ["เดี๋ยว", "deaw"],
  ["เดี๋ยวนะ", "diaona"], ["รอแป๊บ", "rorpaep"], ["แป๊บนึง", "paepnueng"], ["นิดนึง", "nitnueng"],
  ["บาย", "bai"], ["บายบาย", "baibai"], ["ฝันดีนะ", "fandeena"], ["ราตรีสวัสดิ์", "ratrisawat"],
  ["อรุณสวัสดิ์", "arunsawat"], ["ยินดีด้วย", "yindeeduay"], ["สุขสันต์วันเกิด", "suksanwankoet"],
  ["โอเคไหม", "okmai"], ["ได้เลย", "dailoei"], ["ได้ครับ", "daikrap"], ["ได้ค่ะ", "daika"],
  ["ไม่เป็นไรครับ", "maipenraikrap"], ["ไม่เป็นไรค่ะ", "maipenraika"], ["ขอบใจ", "khopjai"], ["ขอบใจ", "kobjai"],
  ["อิอิ", "ii"], ["555", "hahaha"], ["555", "555"], ["ฮ่าๆ", "haha"], ["ฮ่าๆ", "hhaha"], ["คิคิ", "kiki"],
  ["เย้", "yay"], ["ว้าว", "wow"], ["โอ้โห", "ohoh"], ["เหรอคะ", "roeka"], ["จริงเหรอ", "jingror"],
  ["มากๆ", "makmak"], ["จริงๆ", "chingching"], ["เร็วๆ", "rewrew"], ["ช้าๆ", "chacha"], ["ดีๆ", "didi"],
  ["เยอะๆ", "yoeyoe"], ["เยอะ", "yer"], ["เยอะ", "yoe"], ["ด้วย", "duay"], ["ด้วย", "duai"],
);

// ---- English words Thais write in Thai -----------------------------------
window.THAI_EXTRA.push(
  ["เฟซบุ๊ก", "facebook"], ["เฟซบุ๊ก", "fb"], ["ไลน์", "line"], ["อีเมล", "email"], ["อินเทอร์เน็ต", "internet"],
  ["ยูทูบ", "youtube"], ["กูเกิล", "google"], ["อินสตาแกรม", "instagram"], ["ไอจี", "ig"], ["แอป", "app"],
  ["ไวไฟ", "wifi"], ["โทรศัพท์", "phone"], ["คอม", "com"], ["โน้ตบุ๊ก", "notebook"], ["ไอโฟน", "iphone"],
  ["แท็บเล็ต", "tablet"], ["เกม", "game"], ["ออนไลน์", "online"], ["ออฟไลน์", "offline"], ["ไฟล์", "file"],
  ["โฟลเดอร์", "folder"], ["ดาวน์โหลด", "download"], ["อัปโหลด", "upload"], ["ล็อกอิน", "login"],
  ["พาสเวิร์ด", "password"], ["รีสตาร์ต", "restart"], ["อัปเดต", "update"], ["ซอฟต์แวร์", "software"],
  ["แชต", "chat"], ["โพสต์", "post"], ["ไลก์", "like"], ["แชร์", "share"], ["คอมเมนต์", "comment"],
  ["รีวิว", "review"], ["ช็อปปิ้ง", "shopping"], ["ห้าง", "mall"], ["กาแฟ", "coffee"], ["ชา", "tea"],
  ["เค้ก", "cake"], ["พิซซ่า", "pizza"], ["แฮมเบอร์เกอร์", "hamburger"], ["ไอศกรีม", "icecream"],
  ["ไอติม", "aitim"], ["ช็อกโกแลต", "chocolate"], ["แท็กซี่", "taxi"], ["บัส", "bus"], ["รถไฟฟ้า", "bts"],
  ["รถไฟใต้ดิน", "mrt"], ["โรงแรม", "hotel"], ["ออฟฟิศ", "office"], ["มีตติ้ง", "meeting"], ["ประชุม", "prachum"],
  ["โปรเจกต์", "project"], ["เดดไลน์", "deadline"], ["บอส", "boss"], ["ทีม", "team"], ["งานปาร์ตี้", "party"],
  ["ปาร์ตี้", "party"], ["คอนเสิร์ต", "concert"], ["หนัง", "movie"], ["ซีรีส์", "series"], ["เพลง", "song"],
  ["ฟุตบอล", "football"], ["ยิม", "gym"], ["ฟิตเนส", "fitness"], ["โยคะ", "yoga"], ["มหาลัย", "mahalai"],
  ["โอเค", "oke"], ["ซอรี่", "sorry"], ["แต๊งกิ้ว", "thankyou"], ["โอเคครับ", "okkrap"], ["โอเคค่ะ", "okka"],
);

// ---- Places ----------------------------------------------------------------
window.THAI_EXTRA.push(
  ["กรุงเทพฯ", "krungthep"], ["กรุงเทพ", "bkk"], ["เชียงใหม่", "chiangmai"], ["เชียงราย", "chiangrai"],
  ["ภูเก็ต", "phuket"], ["พัทยา", "pattaya"], ["อยุธยา", "ayutthaya"], ["อยุธยา", "ayuthaya"],
  ["ขอนแก่น", "khonkaen"], ["โคราช", "korat"], ["นครราชสีมา", "nakhonratchasima"], ["หาดใหญ่", "hatyai"],
  ["กระบี่", "krabi"], ["เกาะสมุย", "kohsamui"], ["สมุย", "samui"], ["หัวหิน", "huahin"], ["อุดรธานี", "udonthani"],
  ["อุบลราชธานี", "ubonratchathani"], ["สุโขทัย", "sukhothai"], ["กาญจนบุรี", "kanchanaburi"], ["ระยอง", "rayong"],
  ["ชลบุรี", "chonburi"], ["นนทบุรี", "nonthaburi"], ["สยาม", "siam"], ["สุขุมวิท", "sukhumvit"],
  ["สีลม", "silom"], ["อโศก", "asok"], ["ทองหล่อ", "thonglor"], ["ทองหล่อ", "tonglor"], ["สนามบิน", "sanambin"],
  ["สุวรรณภูมิ", "suvarnabhumi"], ["ดอนเมือง", "donmueang"], ["ญี่ปุ่น", "japan"], ["อเมริกา", "america"],
  ["อังกฤษ", "england"], ["จีน", "china"], ["เกาหลี", "korea"], ["ลาว", "laos"], ["พม่า", "myanmar"],
);

// ---- Common two-word combinations the corpus splits -------------------------
window.THAI_EXTRA.push(
  ["ด้วยกัน", "duaykan"], ["ด้วยกัน", "duaikan"], ["รู้จัก", "ruchak"], ["รู้จัก", "rujak"], ["ห้องน้ำ", "hongnam"],
  ["ที่ไหน", "thinai"], ["ไหมครับ", "maikrap"], ["ไหมคะ", "maika"], ["หรือเปล่า", "ruepalao"], ["รึเปล่า", "ruplao"],
  ["เมื่อกี้", "mueaki"], ["เมื่อกี้", "muaki"], ["ตอนเช้า", "tonchao"], ["ตอนเย็น", "tonyen"], ["คืนนี้", "khuenni"],
  ["คืนนี้", "kuennee"], ["สุดสัปดาห์", "sutsapda"], ["เสาร์อาทิตย์", "saoathit"], ["วันหยุด", "wanyut"],
);

// ---- Everyday conversation (one entry per phrase, textbook spelling; the sound
// map covers the casual spellings) -----------------------------------------------
window.THAI_EXTRA.push(
  // greetings / small talk
  ["สบายดีไหม", "sabaidimai"], ["สบายดีครับ", "sabaidikhrap"], ["สบายดีค่ะ", "sabaidikha"], ["แล้วคุณล่ะ", "laeokhunla"],
  ["ไม่ได้เจอกันนาน", "maidaichoekannan"], ["คิดถึงนะ", "khitthuengna"], ["คิดถึงมาก", "khitthuengmak"],
  ["ยินดีที่ได้รู้จัก", "yindithidairuchak"], ["ฝากเนื้อฝากตัว", "faknueafaktua"], ["เป็นยังไงบ้าง", "penyangngaibang"],
  ["ทำอะไรอยู่", "thamaraiyu"], ["กินข้าวหรือยัง", "kinkhaorueyang"], ["กินแล้ว", "kinlaeo"], ["ยังไม่ได้กิน", "yangmaidaikin"],
  ["ไปไหนมา", "painaima"], ["กลับบ้าน", "klapban"], ["ถึงบ้านแล้ว", "thuengbanlaeo"], ["ถึงแล้ว", "thuenglaeo"],
  ["เดินทางปลอดภัย", "doenthangplotphai"], ["โชคดีนะ", "chokdina"], ["เจอกันพรุ่งนี้", "choekanphrungni"],
  ["เจอกันใหม่", "choekanmai"], ["ไว้เจอกัน", "waichoekan"], ["ไปก่อนนะ", "paikonna"], ["ไปแล้วนะ", "pailaeona"],
  ["ราตรีสวัสดิ์", "ratrisawat"], ["นอนหลับฝันดี", "nonlapfandi"], ["ตื่นแล้ว", "tuenlaeo"], ["ตื่นยัง", "tuenyang"],
  // feelings / reactions
  ["ดีใจด้วย", "dichaiduai"], ["เสียใจด้วย", "siachaiduai"], ["ไม่เป็นไรหรอก", "maipenraiwok"], ["ไม่เป็นไรนะ", "maipenraina"],
  ["เหนื่อยมาก", "nueaimak"], ["ง่วงนอน", "nguangnon"], ["หิวข้าว", "hiwkhao"], ["หิวมาก", "hiwmak"], ["อิ่มแล้ว", "imlaeo"],
  ["เบื่อ", "buea"], ["เบื่อมาก", "bueamak"], ["เครียด", "khriat"], ["สนุกมาก", "sanukmak"], ["ตลกมาก", "talokmak"],
  ["น่ารักมาก", "naraknak"], ["น่ารักจัง", "narakchang"], ["สวยมาก", "suaimak"], ["เก่งมาก", "kengmak"], ["เยี่ยมมาก", "yiammak"],
  ["ใจเย็นๆ", "chaiyenyen"], ["ไม่ต้องห่วง", "maitonghuang"], ["ไม่ต้องกังวล", "maitongkangwon"], ["สู้ๆ", "susu"],
  ["เป็นห่วง", "penhuang"], ["ขอให้โชคดี", "khohaichokdi"], ["ตกใจ", "tokchai"], ["งง", "ngong"], ["งงมาก", "ngongmak"],
  // requests / help
  ["ช่วยด้วย", "chuaiduai"], ["ช่วยหน่อย", "chuainoi"], ["ช่วยได้ไหม", "chuaidaimai"], ["ขอหน่อย", "khonoi"],
  ["ขอโทษนะ", "khothotna"], ["ขอโทษครับ", "khothotkhrap"], ["ขอโทษค่ะ", "khothotkha"], ["ขอบคุณมาก", "khopkhunmak"],
  ["ขอบคุณมากครับ", "khopkhunmakkhrap"], ["ขอบคุณมากค่ะ", "khopkhunmakkha"], ["ขอบคุณนะ", "khopkhunna"],
  ["รอสักครู่", "rosakkhru"], ["รอแป๊บนึง", "ropaepnueng"], ["เดี๋ยวมา", "diaoma"], ["เดี๋ยวโทรกลับ", "diaothoklap"],
  ["โทรหาหน่อย", "thohanoi"], ["ส่งไลน์มา", "songlainma"], ["ส่งรูปมา", "songrupma"], ["พูดช้าๆ", "phutchacha"],
  ["พูดอีกที", "phutikthi"], ["ไม่เข้าใจ", "maikhaochai"], ["เข้าใจแล้ว", "khaochailaeo"], ["ไม่รู้", "mairu"],
  ["ไม่แน่ใจ", "mainaechai"], ["แน่นอน", "naenon"], ["ได้สิ", "daisi"], ["ไม่ได้หรอก", "maidairok"], ["ก็ได้", "kodai"],
  ["ตามใจ", "tamchai"], ["แล้วแต่", "laeotae"], ["แล้วแต่คุณ", "laeotaekhun"], ["เอาเลย", "aoloei"], ["ไม่เอา", "maiao"],
  // questions
  ["ทำไมล่ะ", "thammaila"], ["ยังไงดี", "yangngaidi"], ["เท่าไหร่ครับ", "thaoraikhrap"], ["เท่าไหร่คะ", "thaoraikha"],
  ["กี่โมง", "kimong"], ["กี่โมงแล้ว", "kimonglaeo"], ["กี่บาท", "kibat"], ["ที่ไหนครับ", "thinaikhrap"],
  ["อยู่ที่ไหน", "yuthinai"], ["ไปยังไง", "paiyangngai"], ["ใช้เวลานานไหม", "chaiwelananmai"], ["ไกลไหม", "klaimai"],
  ["มีไหม", "mimai"], ["ได้ไหม", "daimai"], ["ใช่ไหม", "chaimai"], ["จริงไหม", "chingmai"], ["ว่างไหม", "wangmai"],
  ["อันนี้คืออะไร", "annikhuearai"], ["อันนี้", "anni"], ["อันนั้น", "annan"], ["คนนี้", "khonni"], ["ที่นี่", "thini"],
  ["ชื่ออะไร", "chuearai"], ["คุณชื่ออะไร", "khunchuearai"], ["อายุเท่าไหร่", "ayuthaorai"], ["มาจากไหน", "machaknai"],
  // food / shopping / travel
  ["หิวแล้ว", "hiwlaeo"], ["ไปกินข้าวกัน", "paikinkhaokan"], ["กินอะไรดี", "kinaraidi"], ["อร่อยมาก", "aroimak"],
  ["ไม่เผ็ด", "maiphet"], ["เผ็ดนิดหน่อย", "phetnitnoi"], ["ไม่ใส่ผัก", "maisaiphak"], ["เช็คบิล", "chekbin"],
  ["เก็บเงินด้วย", "kepngoenduai"], ["ลดได้ไหม", "lotdaimai"], ["แพงไป", "phaengpai"], ["ถูกมาก", "thukmak"],
  ["ข้าวผัด", "khaophat"], ["ผัดไทย", "phatthai"], ["ส้มตำ", "somtam"], ["ต้มยำกุ้ง", "tomyamkung"], ["ข้าวมันไก่", "khaomankai"],
  ["กะเพรา", "kaphrao"], ["ผัดกะเพรา", "phatkaphrao"], ["ชาเย็น", "chayen"], ["น้ำเปล่า", "namplao"], ["กาแฟเย็น", "kafaeyen"],
  ["ไปสนามบิน", "paisanambin"], ["เลี้ยวซ้าย", "liaosai"], ["เลี้ยวขวา", "liaokhwa"], ["ตรงไป", "trongpai"],
  ["จอดตรงนี้", "chottrongni"], ["รถติด", "rotthit"], ["รถติดมาก", "rottitmak"], ["ใกล้แล้ว", "klailaeo"],
  // time / plans
  ["วันนี้", "wanni"], ["เมื่อวานนี้", "mueawanni"], ["พรุ่งนี้เช้า", "phrungnichao"], ["ตอนเย็นนี้", "tonyenni"],
  ["อาทิตย์หน้า", "athitna"], ["เดือนหน้า", "dueanna"], ["ปีหน้า", "pina"], ["เมื่อไหร่ก็ได้", "muearaikodai"],
  ["ว่างเมื่อไหร่", "wangmuearai"], ["ไม่ว่าง", "maiwang"], ["ติดงาน", "titngan"], ["เลิกงาน", "loekngan"],
  ["ทำงานอยู่", "thamnganyu"], ["ประชุมอยู่", "prachumyu"], ["กำลังไป", "kamlangpai"], ["กำลังจะไป", "kamlangchapai"],
  ["เดี๋ยวไป", "diaopai"], ["ถึงไหนแล้ว", "thuengnailaeo"], ["ใกล้ถึงแล้ว", "klaithuenglaeo"], ["ขอโทษที่มาสาย", "khothotthimasai"],
  // love / family
  ["รักนะ", "rakna"], ["รักมาก", "rakmak"], ["รักคุณ", "rakkhun"], ["ผมรักคุณ", "phomrakkhun"], ["ฉันรักคุณ", "chanrakkhun"],
  ["รักเธอ", "rakthoe"], ["คิดถึงเธอ", "khitthuengthoe"], ["ที่รัก", "thirak"], ["พ่อแม่", "phomae"], ["ครอบครัว", "khropkhrua"],
  ["พี่น้อง", "phinong"], ["ลูก", "luk"], ["แฟนผม", "faenphom"], ["แฟนฉัน", "faenchan"], ["เพื่อนสนิท", "phueansanit"],
);

// ---- Set phrases and idioms ------------------------------------------------------
window.THAI_EXTRA.push(
  ["กาลครั้งหนึ่ง", "kankhrangnueng"], ["กาลครั้งหนึ่ง", "kanlakhrangnueng"], ["กาลครั้งหนึ่ง", "kanrakhrangnueng"],
  ["กาลครั้งหนึ่ง", "ganrakrungneung"], ["กาลครั้งหนึ่ง", "gankrangneung"], ["นานมาแล้ว", "nanmalaeo"],
  ["มาแล้ว", "malaeo"], ["ครั้งหนึ่ง", "khrangnueng"], ["ครั้งหน้า", "khrangna"], ["ครั้งแรก", "khrangraek"],
  ["ครั้งสุดท้าย", "khrangsutthai"], ["อีกครั้ง", "ikkhrang"], ["ในที่สุด", "naithisut"], ["อยู่มาวันหนึ่ง", "yumawannueng"],
  ["มีความสุข", "mikhwamsuk"], ["ตลอดไป", "talotpai"], ["ผลไม้", "phonlamai"], ["ผลไม้", "polamai"], ["ทุกวัน", "thukwan"],
  ["ทุกคน", "thukkhon"], ["ไม่เคย", "maikhoei"], ["เคย", "khoei"], ["เคย", "koey"],
  ["กะเพรา", "krapao"], ["กะเพรา", "kaprao"], ["ผัดกะเพรา", "padkrapao"], ["ผัดกะเพรา", "padkaprao"],
  ["กับข้าว", "kapkhao"], ["ต้มยำ", "tomyum"], ["ส้มตำ", "somtum"],
);

// ---- "u" written for the short a sound (English "fun") ------------------------
// Listed one by one rather than as a rule: a blanket u->a rule would also turn
// "khun" (คุณ) into การ. These make the a-word an exact match, so the more common
// word wins: "krung" gives ครั้ง (48,705 uses) before กรุง (5,257).
window.THAI_EXTRA.push(
  ["ครั้ง", "krung"], ["ครั้ง", "khrung"], ["ทำ", "tum"], ["ทำ", "thum"], ["ฉัน", "chun"], ["หนัง", "nung"],
  ["กับ", "kub"], ["ครับ", "krub"], ["ครับ", "khrub"], ["สำหรับ", "sumrub"], ["สำหรับ", "samrub"], ["รัก", "ruk"],
  ["ทั้ง", "tung"], ["ทั้งหมด", "tungmod"], ["ยัง", "yung"], ["ฟัง", "fung"], ["นั่ง", "nung"], ["หลัง", "lung"],
  ["ตั้ง", "tung"], ["พัง", "pung"], ["ดัง", "dung"], ["จัง", "jung"], ["ขับ", "kub"], ["รับ", "rub"],
  ["จับ", "jub"], ["นับ", "nub"], ["หลับ", "lub"], ["ลับ", "lub"], ["ทัน", "tun"], ["มัน", "mun"], ["วัน", "wun"],
  ["ฝัน", "fun"], ["ขัน", "kun"].slice(0, 0), ["สัญญา", "sunya"], ["บัญชี", "bunchee"], ["ดัง", "dung"],
  ["ตัด", "tud"], ["นัด", "nud"], ["หัด", "hud"], ["จัด", "jud"], ["วัด", "wud"], ["สัก", "suk"].slice(0, 0),
  ["ผัก", "puk"], ["พัก", "puk"], ["รักษา", "ruksa"], ["ทำงาน", "tumngan"], ["ทำไม", "tummai"], ["ฉันรักคุณ", "chunrukkun"],
  ["รักคุณ", "rukkun"], ["รักกัน", "rukkun"].slice(0, 0), ["ผัดไทย", "pudthai"], ["กับข้าว", "kubkao"],
);
window.THAI_EXTRA = window.THAI_EXTRA.filter((x) => x.length === 2);

// ---- Internet slang (newer than the corpus) --------------------------------------
window.THAI_EXTRA.push(
  ["ฟิน", "fin"], ["ปัง", "pang"], ["ปังมาก", "pangmak"], ["จึ้ง", "jueng"], ["จึ้ง", "jeung"], ["แซ่บ", "saep"],
  ["แซ่บ", "zaap"], ["แซ่บ", "sab"], ["ชิล", "chill"], ["ชิลๆ", "chillchill"], ["ชิว", "chiw"], ["ชิวๆ", "chiwchiw"],
  ["เท", "te"], ["โดนเท", "dontae"], ["แกง", "kaeng"], ["โดนแกง", "donkaeng"], ["นก", "nok"], ["เกรียน", "krian"],
  ["มโน", "mano"], ["ดราม่า", "drama"], ["เผือก", "phueak"], ["เผือก", "puak"], ["จิ้น", "jin"], ["ติ่ง", "ting"],
  ["ฟีล", "feel"], ["ฟีลดี", "feeldee"], ["ซีน", "scene"], ["มูฟออน", "moveon"], ["เป๊ะ", "pe"], ["เป๊ะมาก", "pemak"],
  ["โป๊ะ", "po"], ["โป๊ะแตก", "potaek"], ["สตรอง", "strong"], ["อวย", "uay"], ["เวิ่น", "woen"], ["เริ่ด", "roet"],
  ["เริ่ด", "rerd"], ["ต๊าช", "tach"], ["ตุ๊ด", "tut"], ["เบียว", "biao"], ["มุ้งมิ้ง", "mungming"], ["ตะมุตะมิ", "tamutami"],
  ["คิ้วท์", "cute"], ["น่ารักอะ", "naraka"], ["งุ้ย", "ngui"], ["งุงิ", "ngungi"], ["อุ๊ย", "ui"], ["ว้าย", "wai"],
  ["เหรอวะ", "rerwa"], ["จริงดิ", "jingdi"], ["ใช่ป่ะ", "chaipa"], ["ป่ะล่ะ", "pala"], ["ไปป่ะ", "paipa"],
  ["เอาป่ะ", "aopa"], ["ได้ป่ะ", "daipa"], ["ว่าไง", "wangai"], ["ว่าไงนะ", "wangaina"], ["แหม", "mae"], ["แหม่", "mae"],
  ["เออ", "oe"], ["เออ", "er"], ["อือ", "ue"], ["อื้อ", "ue"], ["อืม", "uem"], ["อืม", "um"], ["อ้าว", "ao"], ["เอ๊ะ", "e"],
  ["โอ้ย", "oi"], ["โอ๊ย", "oy"], ["เฮ้ย", "hoei"], ["เฮ้ย", "hey"], ["เห้ย", "hoei"], ["ห๊ะ", "ha"], ["หา", "ha"],
  ["555", "55"], ["555", "5555"], ["555", "lol"], ["ฮ่าๆๆ", "hahahaha"], ["ขำ", "kham"], ["ขำมาก", "khammak"],
  ["ตลก", "talok"], ["ตลกอะ", "taloka"], ["งง", "ngong"], ["งงอะ", "ngonga"], ["เซ็ง", "seng"], ["เซ็งมาก", "sengmak"],
  ["เบื่ออะ", "bueaa"], ["เหงา", "ngao"], ["เหงาจัง", "ngaojang"], ["คิดถึงอะ", "kidtueng-a"], ["รักนะจุ๊บๆ", "raknajubjub"],
  ["จุ๊บๆ", "jubjub"], ["จุ๊บ", "jub"], ["บ๊ายบาย", "byebye"], ["ฝันดีจ้า", "fandeeja"], ["ขอบคุณจ้า", "kobkunja"],
  ["โอเคจ้า", "okja"], ["ได้จ้า", "daija"], ["ค่าาา", "kaaa"], ["ครับผม", "kubpom"], ["ครับป๋ม", "krubpom"],
);

// ---- Everyday spellings the sound rules read as another vowel ----------------------
// (a plain "a" for แ and "eo" for เอียว are handled by the engine; these are the ones
// common enough to come first.)
window.THAI_EXTRA.push(
  ["แกง", "gang"], ["แล้ว", "leow"], ["แล้ว", "lew"], ["แมว", "meow"], ["เงิน", "ngen"], ["เงิน", "ngern"],
);
