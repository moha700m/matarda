extends Node

signal locale_changed

var _table := {
	"title": {"en": "MATARDA", "ar": "مطاردة"},
	"tagline": {"en": "Cops versus robbers", "ar": "شرطة ضد مجرمين"},
	"copyright": {"en": "Copyright © Mohammed", "ar": "حقوق النشر © محمد"},
	"guest_name": {"en": "Guest name", "ar": "اسم الضيف"},
	"play": {"en": "Play", "ar": "العب"},
	"settings": {"en": "Settings", "ar": "الإعدادات"},
	"quit": {"en": "Quit", "ar": "خروج"},
	"language": {"en": "Language", "ar": "اللغة"},
	"back": {"en": "Back", "ar": "رجوع"},
	"rooms": {"en": "Rooms", "ar": "الغرف"},
	"room_hint": {"en": "Join by IP or pick a saved room.", "ar": "انضم بعنوان الشبكة أو اختر غرفة محفوظة."},
	"ip": {"en": "IP address", "ar": "عنوان IP"},
	"port": {"en": "Port", "ar": "المنفذ"},
	"add": {"en": "Add", "ar": "إضافة"},
	"join": {"en": "Join", "ar": "انضمام"},
	"host": {"en": "Host", "ar": "استضافة"},
	"refresh": {"en": "Refresh", "ar": "تحديث"},
	"players": {"en": "Players", "ar": "اللاعبون"},
	"connecting": {"en": "Connecting…", "ar": "جارٍ الاتصال…"},
	"connect_fail": {"en": "Could not connect", "ar": "تعذر الاتصال"},
	"hosted": {"en": "Room open. Others join this machine.", "ar": "الغرفة مفتوحة. ينضم الآخرون إلى هذا الجهاز."},
	"character": {"en": "Character", "ar": "الشخصية"},
	"outfit": {"en": "Outfit", "ar": "الزي"},
	"next": {"en": "Next", "ar": "التالي"},
	"team": {"en": "Choose a team", "ar": "اختر الفريق"},
	"police": {"en": "Police", "ar": "الشرطة"},
	"criminals": {"en": "Criminals", "ar": "المجرمون"},
	"police_blurb": {"en": "Stop the robbery. Arrest or run out the clock.", "ar": "أوقف السرقة. اقبض أو أنهِ الوقت."},
	"criminal_blurb": {"en": "Rob the bank vault and carry the loot out.", "ar": "اسرق خزنة المصرف وأوصل الغنيمة."},
	"confirm": {"en": "Confirm", "ar": "تأكيد"},
	"graphics": {"en": "Graphics", "ar": "الرسوم"},
	"low": {"en": "Low", "ar": "منخفض"},
	"medium": {"en": "Medium", "ar": "متوسط"},
	"high": {"en": "High", "ar": "عالٍ"},
	"sound": {"en": "Sound", "ar": "الصوت"},
	"master": {"en": "Master", "ar": "الرئيسي"},
	"sfx": {"en": "Effects", "ar": "المؤثرات"},
	"controls": {"en": "Controls", "ar": "التحكم"},
	"control_size": {"en": "Control size", "ar": "حجم الأزرار"},
	"opacity": {"en": "Opacity", "ar": "الشفافية"},
	"layout": {"en": "Layout", "ar": "التخطيط"},
	"right_handed": {"en": "Right handed", "ar": "أيمن"},
	"left_handed": {"en": "Left handed", "ar": "أعسر"},
	"health": {"en": "Health", "ar": "الصحة"},
	"cash": {"en": "Cash", "ar": "المال"},
	"mission": {"en": "Mission", "ar": "المهمة"},
	"waiting": {"en": "Waiting for players", "ar": "بانتظار اللاعبين"},
	"obj_go_bank": {"en": "Reach the bank vault", "ar": "اوصل إلى خزنة المصرف"},
	"obj_hold": {"en": "Hold the bank", "ar": "اثبت داخل المصرف"},
	"obj_loot": {"en": "Pick up the loot", "ar": "التقط الغنيمة"},
	"obj_escape": {"en": "Carry the loot to the escape point", "ar": "أوصل الغنيمة إلى نقطة الهروب"},
	"obj_police": {"en": "Stop the crew before they escape", "ar": "أوقف العصابة قبل الهروب"},
	"obj_down": {"en": "You are down", "ar": "أنت مصاب"},
	"interact_rob": {"en": "Interact — start robbery", "ar": "تفاعل — ابدأ السرقة"},
	"interact_loot": {"en": "Interact — take loot", "ar": "تفاعل — خذ الغنيمة"},
	"interact_arrest": {"en": "Interact — arrest", "ar": "تفاعل — قبض"},
	"shoot": {"en": "Fire", "ar": "إطلاق"},
	"jump": {"en": "Jump", "ar": "قفز"},
	"crouch": {"en": "Crouch", "ar": "انحناء"},
	"sprint": {"en": "Sprint", "ar": "ركض"},
	"interact": {"en": "Use", "ar": "استخدم"},
	"pause": {"en": "Pause", "ar": "إيقاف"},
	"resume": {"en": "Resume", "ar": "متابعة"},
	"disconnect": {"en": "Leave match", "ar": "مغادرة المباراة"},
	"police_win": {"en": "Police win", "ar": "فازت الشرطة"},
	"criminal_win": {"en": "Criminals win", "ar": "فاز المجرمون"},
	"bank": {"en": "BANK", "ar": "المصرف"},
	"station": {"en": "POLICE", "ar": "الشرطة"},
	"escape": {"en": "ESCAPE", "ar": "هروب"},
	"sunset_room": {"en": "Sunset District", "ar": "حي الغروب"},
	"restored": {"en": "Session restored", "ar": "تمت استعادة الجلسة"},
	"variant_plain": {"en": "Plain", "ar": "بسيط"},
	"variant_vest": {"en": "Vest", "ar": "سترة"},
	"variant_cap": {"en": "Cap", "ar": "قبعة"},
	"variant_jacket": {"en": "Jacket", "ar": "معطف"},
	"map_label": {"en": "Map", "ar": "الخريطة"},
	"score": {"en": "Score", "ar": "النقاط"},
}

func _ready() -> void:
	Settings.changed.connect(_on_settings)
	_apply()

func _on_settings() -> void:
	_apply()

func _apply() -> void:
	locale_changed.emit()

func t(key: String) -> String:
	var row = _table.get(key)
	if row == null:
		return key
	var code := Settings.locale if Settings.locale == "ar" else "en"
	return str(row.get(code, row.get("en", key)))

func is_rtl() -> bool:
	return Settings.locale == "ar"

func direction() -> Control.TextDirection:
	return Control.TEXT_DIRECTION_RTL if is_rtl() else Control.TEXT_DIRECTION_LTR

func layout() -> Control.LayoutDirection:
	return Control.LAYOUT_DIRECTION_RTL if is_rtl() else Control.LAYOUT_DIRECTION_LTR

func outfit_name(index: int) -> String:
	match index:
		1:
			return t("variant_vest")
		2:
			return t("variant_cap")
		3:
			return t("variant_jacket")
		_:
			return t("variant_plain")
