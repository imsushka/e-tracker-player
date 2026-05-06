	.ORG    0100h

	ld	a, 1Ch
	out	($C5), a
	ld	a, 02h
	out	($C4), a	;иництализация микросхемы

	ld	hl, $1000      			;адрес музыки
	call	EPlayer_Init

	ld	a, 0
	ld	(press), a

	ld	a, 1Ch
	out	($C5), a
	ld	a, 01h
	out	($C4), a

loop:
	call	waittof			; wait top of frame, c times
	call	EPlayer_Play
	ld	a, (press)
	inc	a
	jR	nz, loop

	ld	a, 1Ch
	out	($C5), a
	ld	a, 02h
	out	($C4), a

	ret

waittof:
_invblanka:
	in	a, (0CFh)
	bit	0, a
	jr	z, _invblanka
_lop1:
	in	a, (0CFh)
	bit	0, a
	jr	nz, _lop1
	
	rst	18h
	jr	z, _exit
	ld	a, 255
	ld	(press), a
_exit:
	ret

press:	.db	0

;--------------------------------------------------------------------
; Описание: Проигрывающий модуль музыкального редактора E-Tracker
; портирован с компьютера Sam Coupe
; Автор порта: Тарасов М.Н.(Mick), 2010
;--------------------------------------------------------------------
;-------------------------------------------------------------------
; описание: Инициализация проигрывателя
; параметры: нет
; возвращаемое значение: нет
;---------------------------------------------------------------------
EPlayer_Init:
		ld	(vModuleStart), hl
		call	getSection
		ld	(vSongTable), bc
		call	getSection
		ld	(vPatterns), bc
		call	getSection
		ld	(vInstruments), bc
		call	getSection
		ld	(vOrnaments), bc
		call	getSection
		ld	a, (bc)
		inc	bc
		ld	(vDefaultVolumeDelay), a
		ld	(vVolumeDelay), bc

;		ld	hl, vModuleStart
;		ld	b, 0h		;размер области служебных данных

		ld	hl, sChannel0
		ld	b, 0B2h		;размер области служебных данных
		xor	a
loc_0001:
		ld	(hl), a		;очищаем служебную область
		inc	hl
		djnz	loc_0001

		inc	a
		ld	(vDelay), a

		ld	ix, sChannel0
		ld	de, 19h		;размер данных для одного канала
		ld	b, 6
loc_0002:
		ld	(ix + 14h), a	; ch.delay.next_ornament  / a = 1
		ld	(ix + 15h), a	; ch.delay.next_instrument / a = 1
		ld	(ix + 16h), a	; ch.delay.next_volume   / a = 1
		ld	hl, instrument_none
		ld	(ix + 0Fh), l	; ch.ptr.instrument.start
		ld	(ix + 10h), h	; ch.ptr.instrument.start + 1
		ld	(ix + 2), l	; ch.ptr.instrument
		ld	(ix + 3), h	; ch.ptr.instrument + 1
		ld	hl, ornament_none
		ld	(ix + 11h), l	; ch.ptr.ornament.start
		ld	(ix + 12h), h	; ch.ptr.ornament.start + 1
		add	ix, de		;переходим к следующему каналу
		djnz	loc_0002

;========================================================
ReadSongTable:
		ld	hl, (vSongTable)
sub_loc_001:
		ld	c, (hl)
		ld	a, c
		inc	hl
		inc	a
		jr	z, loc_if_FF
		inc	a
		jr	z, loc_if_FE
		sub	62h
		jr	nc, loc_if_60
		ld	(vSongTable), hl
		sla	c

		ld	hl, (vPatterns)
		call	getSectionC
		ld	(sChannel0), bc
		call	getSection
		ld	(sChannel1), bc
		call	getSection
		ld	(sChannel2), bc
		call	getSection
		ld	(sChannel3), bc
		call	getSection
		ld	(sChannel4), bc
		call	getSection
		ld	(sChannel5), bc
		ret	
;song_table.get_loop
loc_if_FF:
		ld	hl, (vSongTableLoop)
		jr	sub_loc_001
;song_table.set_loop
loc_if_FE:
		ld	(vSongTableLoop), hl
		jr	sub_loc_001
;song_table.set_height
loc_if_60:
		ld	(vPatternHeight), a	; var.pattern.height
		jr	sub_loc_001
;========================================================


;=======================================================
;-------------------------------------------------------------------
; описание: Проигрывание текущей ноты
; параметры: нет
; возвращаемое значение: нет
;---------------------------------------------------------------------

EPlayer_Play:
		ld	iy, Variable

		ld	a, (vDelay)
		dec	a
		jr	nz, loc_0_802A

		ld	ix, sChannel0
		ld	b, 6		; число каналов

loc_0_8011:
		push	bc
		call	get_note
		ld	bc, 19h		; количество байт для одного канала
		add	ix, bc
		pop	bc
		djnz	loc_0_8011
; ----
		ld	hl, (vNoise0)
		ld	a, h
		call	swap_nibbles
		or	l
		ld	(iy + 21h), a ; ld (vNoiseExtended + 1), a

		ld	a, (vTuneDelay)

loc_0_802A:
		ld	(vDelay), a
; ----
		ld	ix, sChannel0        
		call	update_channel
		ld	(iy + 00h), a ;ld	(EAmplitude_ch0), a        ;Amplitude 0 right/left
		ld	(iy + 08h), l ;ld	(EFrequency_ch0), hl
		push	hl
		ld	hl, 0
		call	get_noise
		ld	(storeNoise), hl
		ld	(iy + 1Fh), a ; ld	(vNoiseGen0 + 1), a

; ----
		ld	ix, sChannel1
		call	update_channel
		ld	(iy + 01h), a ;ld	(EAmplitude_ch1), a        ;Amplitude 1 right/left
		ld	(iy + 09h), l ;ld	(EFrequency_ch1), hl
		push	hl
		ld	hl, (storeNoise)
		call	get_noise
		ld	(storeNoise), hl
		rl	h
		jr	nc, no_noise0
		ld	(iy + 1Fh), a ; ld	(vNoiseGen0 + 1), a

; ----
no_noise0:
		ld	ix, sChannel2
		call	update_channel
		ld	(iy + 02h), a ;ld	(EAmplitude_ch2), a		;Amplitude 2 right/left
		ld	(iy + 0Ah), l ;ld	(EFrequency_ch2), hl
		push	hl
		ld	hl, (storeNoise)
		call	get_noise
		ld	(storeNoise), hl
		rl	h
		jr	nc, no_noise1
		ld	(iy + 1Fh), a ; ld	(vNoiseGen0 + 1), a

; ----
no_noise1:
		ld	ix, sChannel3
		call	update_channel
		ld	(iy + 03h), a ;ld	(EAmplitude_ch3), a		;Amplitude 3 right/left
		ld	(iy + 0Bh), l ;ld	(EFrequency_ch3), hl
		push	hl
		ld	hl, (storeNoise)
		call	get_noise
		ld	(storeNoise), hl
		ld	(iy + 20h), a ; ld	(vNoiseGen1 + 1), a

; ----
		ld	ix, sChannel4
		call	update_channel
		ld	(iy + 04h), a ;ld	(EAmplitude_ch4), a		;Amplitude 4 right/left
		ld	(iy + 0Ch), l ;ld	(EFrequency_ch4), hl
		push	hl
		ld	hl, (storeNoise)
		call	get_noise
		ld	(storeNoise), hl
		rl	h
		jr	nc, no_noise2
		ld	(iy + 20h), a ; ld	(vNoiseGen1 + 1), a

; ----
no_noise2:
		ld	ix, sChannel5
		call	update_channel
		ld	(iy + 05h), a ;ld	(EAmplitude_ch5), a        ;Amplitude 5 right/left
		ld	(iy + 0Dh), l ;ld	(EFrequency_ch5), hl
		push	hl
		ld	hl, (storeNoise)
		call	get_noise
		rr	l
		rr	l
		rr	h
		rr	h
		ld	(EFrequency_en), hl        ;Freqency and Noise enable
		rlca	
		jr	c, no_noise3

;vNoiseGen1:
		ld	a, (iy + 20h)
		rlca	

no_noise3:
		rlca	
		rlca	
		rlca	
;vNoiseGen0:
		or	(iy + 1Fh)
;vNoiseExtended:
		or	(iy + 21h)
		ld	(ENoise_gen), a			;Noise generator 0 and 1
		pop	af
		pop	bc
		call	swap_nibbles
		or	b
		ld	(EOctave_ch4), a        ;Octave 5 and 4
;		ld	h, a
		pop	af
		pop	bc
		call	swap_nibbles
		or	b
;		ld	l, a
;		ld	(EOctave_ch2), hl		;Octave 2 and 3 and 4 and 5
		ld	(EOctave_ch2), a        ;Octave 3 and 2
		pop	af
		pop	bc
		call	swap_nibbles
		or	b
		ld	(EOctave_ch0), a        ;Octave 1 and 0

;		ld	a, 1Ch
;		out	($C5), a
;		ld	a, 01h
;		out	($C4), a

		ld	hl, EEnvelope_gen1       ;таблица данных звукового канала
		ld	d, 19h             ;размер данных для одного канала

loc_0_8114:
		ld	a, d
		out	($C5), a
		ld	a, (hl)
		out	($C4), a

		dec	d                ;следующий байт
		ret	m                ;выход по окончании записи
		dec	hl               ;переходим к следующим значениям
		jr	loc_0_8114           ;продолжим запись в порт

;=======================================================
frequency_note:
		.db  5 ; B 
		.db 21h ; C 
		.db 3Ch ; C#
		.db 55h ; D 
		.db 6Dh ; D#
		.db 84h ; E 
		.db 99h ; F 
		.db 0ADh ; F#
		.db 0C0h ; G 
		.db 0D2h ; G#
		.db 0E3h ; A 
		.db 0F3h ; A#
;=======================================================
instrument_none:
		.db 0FEh ; set loop
		.db  1  
		.db  0  
		.db  0  
		.db 0FCh ; get loop

;=======================================================
list_envelopes:
		.db  0 
		.db 96h 
		.db 9Eh 
		.db 9Ah 
		.db 86h 
		.db 8Eh 
		.db 8Ah 
		.db 97h 
		.db 9Fh 
		.db 9Bh 
		.db 87h 
		.db 8Fh 
		.db 8Bh 

;  @enabled: equ saa.envelope.enabled
;  @bits.3: equ saa.envelope.bits.3
;  @bits.4: equ saa.envelope.bits.4
;  @same:  equ saa.envelope.left_right.same
;  @inverse: equ saa.envelope.left_right.inverse

;  defb @same  | @bits.4 | saa.envelope.mode.zero      | saa.envelope.reset

;  defb @same  | @bits.3 | saa.envelope.mode.repeat_decay  | @enabled  ; 1
;  defb @same  | @bits.3 | saa.envelope.mode.repeat_attack  | @enabled  ; 2
;  defb @same  | @bits.3 | saa.envelope.mode.repeat_triangle | @enabled  ; 3

;  defb @same  | @bits.4 | saa.envelope.mode.repeat_decay  | @enabled  ; 4
;  defb @same  | @bits.4 | saa.envelope.mode.repeat_attack  | @enabled  ; 5
;  defb @same  | @bits.4 | saa.envelope.mode.repeat_triangle | @enabled  ; 5

;  defb @inverse | @bits.3 | saa.envelope.mode.repeat_decay  | @enabled  ; 7
;  defb @inverse | @bits.3 | saa.envelope.mode.repeat_attack  | @enabled  ; 8
;  defb @inverse | @bits.3 | saa.envelope.mode.repeat_triangle | @enabled  ; 9

;  defb @inverse | @bits.4 | saa.envelope.mode.repeat_decay  | @enabled  ; A
;  defb @inverse | @bits.4 | saa.envelope.mode.repeat_attack  | @enabled  ; B
;  defb @inverse | @bits.4 | saa.envelope.mode.repeat_triangle | @enabled  ; C

;=======================================================
ornament_none:
		.db 0FEh ; set loop
		.db  0  
		.db 0FFh ; get loop

;=======================================================
list_commands:
  .DB  $d2            ; [&d2-&ff] -> c = [&00-&2d]
  .DB  cmdSetDelayNextNote	- cmdOffset

  .DB  $72            ; [&72-&d2] -> c = [&00-&60]
  .DB  cmdSetNote		- cmdOffset

  .DB  $52            ; [&52-&71] -> c = [&00-&1f]
  .DB  cmdSetInstrument		- cmdOffset

  .DB  $51            ; [&51]   -> c = &00
  .DB  cmdEndOfTrack		- cmdOffset

  .DB  $50            ; [&50]   -> c = &00
  .DB  cmdStopSound		- cmdOffset

  .DB  $30            ; [&30-&4f] -> c = [&00-&1f]
  .DB  cmdSetOrnament		- cmdOffset

  .DB  $2e            ; [&2e-&2f] -> c = [&00-&01]
  .DB  cmdInstrumentInversion	- cmdOffset

  .DB  $21            ; [&21-2&d] -> c = [&00-&0c]
  .DB  cmdEnvelope		- cmdOffset

  .DB  $11            ; [&11-&20] -> c = [&00-&0f]
  .DB  cmdVolumeReduction	- cmdOffset

  .DB  $0f            ; [&0f-&10] -> c = [&00-&01]
  .DB  cmdExtendedNoise		- cmdOffset

  .DB  $00            ; [&00-&0f] -> c = [&00-&0f]
  .DB  cmdTuneDelay		- cmdOffset

;======================================================
swap_nibbles:
		rlca	
		rlca	
		rlca	
		rlca	
		ret	
;=======================================================

;=======================================================
get_noise:
		ex	af, af'
		rrca	
		rr	l
		rrca	
		rr	h
		ret	
;=======================================================

;=======================================================
; input
;  hl = index
;  c = section

; output
;  bc = address
;----------------------------------------------
getSectionC:
		sla	c
		ld	b, 0
		add	hl, bc

;======================================================
getSection:
		ld	c, (hl)				;читаем младший байт адреса смещения
		inc	hl
		ld	b, (hl)             ;читаем старший байт адреса смещения
		inc	hl               ;переходим к следующему адресу
		push	hl
		ld	hl, (vModuleStart)      ;адрес музыки
		add	hl, bc             ;получим адрес таблицы
		ld	c, l              ;младший байт адреса
		ld	b, h              ;старший байт адреса
		pop	hl
		ret	
;=======================================================


;=======================================================
; in: c = Instrument number [&00-&1f]
cmdSetInstrument:
		ld	hl, (vInstruments)
		call	getSectionC
		ld	(ix + 0Fh), c	; ch.ptr.instrument.start
		ld	(ix + 10h), b	; ch.ptr.instrument.start + 1
		ld	hl, instrument_none
		ld	(ix + 4), l	; ch.ptr.instrument.loop
		ld	(ix + 5), h	; ch.ptr.instrument.loop + 1
		jr	SetInstrument
;=======================================================
; in: c = Ornament number [&00-&1f]
cmdSetOrnament:
		ld	hl, (vOrnaments)
		call	getSectionC
		ld	(ix + 11h), c	; ch.ptr.ornament.start
		ld	(ix + 12h), b	; ch.ptr.ornament.start + 1
		ld	hl, ornament_none
		ld	(ix + 8), l	; ch.ptr.ornament.loop
		ld	(ix + 9), h	; ch.ptr.ornament.loop + 1
		jr	SetOrnament
;=======================================================
; input
;  b = counter channel
;      6    0 freq noise generator 0
;      5    1 freq internal envelope clock
;      4    2

;      3    3 freq noise generator 1
;      2    4 freq internal envelope clock
;      1    5
;  ix = ptr.channel
;
; BUG: envelope set in channel 3 sets incorrect envelope generator
get_note:
		dec	(ix + 13h)	; ch.delay.next_note
		ret	p
		ld	a, b
		cp	3
		ld	hl, EEnvelope_gen0
		jr	nc, loc_0_81B1
		inc	hl
loc_0_81B1:
		ld	(ptrEnvelopeGenerator), hl
getNoteAgain:
		ld	e, (ix + 0)	; ch.ptr.track
		ld	d, (ix + 1)	; ch.ptr.track + 1
getCommand:
		ld	hl, list_commands - 1
loc_Find:
		ld	a, (de)
		inc	hl
		sub	(hl)
		inc	hl
		jr	c, loc_Find
		inc	de
		ld	c, a
		ld	a, (hl)
		ld	(loc_0_81C9 + 1), a
loc_0_81C9:
smcCommandJr:
		jr	loc_0_81C9

cmdOffset:  .equ smcCommandJr + 2
;=======================================================
; in: c = note [&00-&60]
cmdSetNote:
		ld	(ix + 0Eh), c	; ch.note
		ld	c, (ix + 0Fh)	; ch.ptr.instrument.start
		ld	b, (ix + 10h)	; ch.ptr.instrument.start + 1
SetInstrument:
		ld	(ix + 2), c	; ch.ptr.instrument
		ld	(ix + 3), b	; ch.ptr.instrument + 1
		ld	c, (ix + 11h)	; ch.ptr.ornament.start
		ld	b, (ix + 12h)	; ch.ptr.ornament.start + 1
SetOrnament:
		ld	(ix + 6), c	; ch.ptr.ornament
		ld	(ix + 7), b	; ch.ptr.ornament + 1
		ld	(ix + 14h), 1	; ch.delay.next_ornament
		ld	(ix + 15h), 1	; ch.delay.next_instrument
		ld	(ix + 16h), 1	; ch.delay.next_volume
		jr	getCommand
;=======================================================
; input
;  c = envelope [&00-&0c]
cmdEnvelope:
		ld	b, 0
		ld	hl, list_envelopes
		add	hl, bc
		ld	a, (hl)
		ld	hl, (ptrEnvelopeGenerator)
		ld	(hl), a
		jr	getCommand
;=======================================================
; input
;  c = [&00-&01]
cmdInstrumentInversion:
		ld	(ix + 17h), c	; ch.instrument.inversion
		jr	getCommand
;=======================================================
; input
;  c = [&00-&0f]
cmdTuneDelay:
		ld	a, c
		inc	a
		ld	(vTuneDelay), a
		jr	getCommand
;=======================================================
; input
;  c = [&00-&0f]
cmdVolumeReduction:
		ld	(ix + 18h), c	; ch.volume.reduction
		jr	getCommand
;=======================================================
; input
;  c = [&00-&01]
cmdExtendedNoise:
		jr	z, cmdExtendedNoiseOff
		ld	c, 3 ; saa.noise_0.variable
cmdExtendedNoiseOff:
		ld	hl, (ptrEnvelopeGenerator)
		inc	hl
		inc	hl
		ld	(hl), c
		jr	getCommand
;=======================================================
cmdStopSound:
		ld	bc, instrument_none
		jr	SetInstrument
;=======================================================
; input
;  c = [&00-&2d]
cmdSetDelayNextNote:
		ld	(ix + 13h), c	; ch.delay.next_note
		ld	(ix + 0), e	; ch.ptr.track
		ld	(ix + 1), d	; ch.ptr.track + 1
		ret	
;=======================================================
cmdEndOfTrack:
		call	ReadSongTable
		jp	getNoteAgain
;=======================================================


;=======================================================
hInstrumentLoopOrDelay:
		cp	7Fh
		jr	z, setInstrumentLoop
		cp	7Eh
		jr	z, getInstrumentLoop
		add	a, 2
		ld	c, a
		jr	hInstrument
setInstrumentLoop:
		ld	(ix + 4), l	; ch.ptr.instrument.loop
		ld	(ix + 5), h	; ch.ptr.instrument.loop + 1
		jr	hInstrument
getInstrumentLoop:
		ld	l, (ix + 4)	; ch.ptr.instrument.loop
		ld	h, (ix + 5)	; ch.ptr.instrument.loop + 1
		jr	hInstrument
;=======================================================
hOrnamentLoopOrDelay:
		inc	a
		jr	z, getOrnamentLoop
		inc	a
		jr	z, setOrnamentLoop
		sub	60h
		ld	c, a
		jr	hOrnament
getOrnamentLoop:
		ld	l, (ix + 8)	; ch.ptr.ornament.loop
		ld	h, (ix + 9)	; ch.ptr.ornament.loop + 1
		jr	hOrnament
setOrnamentLoop:
		ld	(ix + 8), l	; ch.ptr.ornament.loop
		ld	(ix + 9), h	; ch.ptr.ornament.loop + 1
		jr	hOrnament

;=======================================================
; input
;  ix = ptr.channel

; output
;  a  =  amplitude
;  l  =  tone
;  a' =  noise
;----------------------------------------------
update_channel:
		ld	e, (ix + 0Ah)	; ch.ptr.instrument.pitch
		ld	d, (ix + 0Bh)	; ch.ptr.instrument.pitch + 1
		dec	(ix + 15h)	; ch.delay.next_instrument
		ld	l, (ix + 2)	; ch.ptr.instrument
		ld	h, (ix + 3)	; ch.ptr.instrument + 1
		jr	nz, noInstrumentChange

		ld	c, 1		; delay.next_instrument
hInstrument:
		ld	a, (hl)
		inc	hl
		rrca	
		jr	nc, hInstrumentLoopOrDelay
		ld	(ix + 15h), c	; ch.delay.next_instrument
		ld	(ix + 0Bh), a	; ch.ptr.instrument.pitch + 1
		ld	e, (hl)
		ld	d, a
		ld	(ix + 0Ah), e	; ch.ptr.instrument.pitch
		inc	hl

noInstrumentChange:
		push	hl
		ld	a, (ix + 0Dh)	; ch.ornament.note
		dec	(ix + 14h)	; ch.delay.next_ornament
		jr	nz, noOrnamentChange

		ld	c, 1		; delay.next_ornament
		ld	l, (ix + 6)	; ch.ptr.ornament
		ld	h, (ix + 7)	; ch.ptr.ornament + 1
hOrnament:
		ld	a, (hl)
		inc	hl
		cp	60h
		jr	nc, hOrnamentLoopOrDelay
		ld	(ix + 14h), c	; ch.delay.next_ornament
		ld	(ix + 0Dh), a	; ch.ornament.note
		ld	(ix + 6), l	; ch.ptr.ornament
		ld	(ix + 7), h	; ch.ptr.ornament + 1

noOrnamentChange:
		add	a, (ix + 0Eh)	; ch.note
		cp	8 * 12 - 1
		ld	hl, 7FFh	; maximum octave (7) + note (&ff)
		jr	z, loc_0_82D1	; max_note
		add	a, (iy + 22h)	; vPatternHeight
		jr	nc, loc_skip0
		sub	60h
loc_skip0:
		ld	hl, 0FF0Ch
		ld	b, h
loc_loop0:
		inc	h
		sub	l
		jr	nc, loc_loop0
		ld	c, a
		ld	a, h
		ld	hl, instrument_none
		add	hl, bc
		ld	l, (hl)
		ld	h, a		; hl = octave + frequency
;max_note:
loc_0_82D1:
		add	hl, de		; de = instrument.pitch
		ld	a, h
		and	7
		ld	h, a
		ld	a, d
		rrca	
		rrca	
		rrca	
		and	0Fh
		ex	af, af'
		ex	de, hl
		pop	hl		; <- @ch.ptr.instrument
		ld	a, (ix + 0Ch)	; ch.volume
		dec	(ix + 16h)	; ch.delay.next_volume
		jr	nz, noVolumeChange
		ld	a, (hl)
		inc	hl
		cp	(iy + 1Eh)	; vDefaultVolumeDelay
		jr	nz, hVolumeDelay
		ld	c, (hl)
		inc	hl
loc_0_82EF:
		ld	a, (hl)
		inc	hl
loc_0_82F1:
		ld	(ix + 16h), c	; ch.delay.next_volume

noVolumeChange:
		ld	(ix + 2), l	; ch.ptr.instrument
		ld	(ix + 3), h	; ch.ptr.instrument + 1
		ld	(ix + 0Ch), a	; ch.volume
		ex	de, hl
		ld	b, (ix + 18h)	; ch.volume.reduction
		ld	c, a
		and	0Fh
		sub	b
		jr	nc, loc_0_8308
		xor	a
loc_0_8308:
		ld	e, a
		ld	a, c
		and	0F0h
		call	swap_nibbles
		sub	b
		jr	nc, loc_0_8313
		xor	a
loc_0_8313:
		ld	d, a
		ld	a, (ix + 17h)	; ch.instrument.inversion
		or	a
		ld	a, e
		jr	nz, loc_0_831D
		ld	a, d
		ld	d, e
loc_0_831D:
		call	swap_nibbles
		or	d
		ret	

;=======================================================
; input
;  a = value to lookup

; output
;  c = value of entry that matches b

hVolumeDelay:
		push	hl
		ld	b, a
		ld	hl, (vVolumeDelay)
loc_0_8327:
		ld	a, (hl)
		or	a
		jr	z, loc_0_8334
		inc	hl
		ld	c, (hl)
		inc	hl
		cp	b
		jr	nz, loc_0_8327
		pop	hl
		jr	loc_0_82EF
loc_0_8334:
		pop	hl
		ld	c, 1
		ld	a, b
		jr	loc_0_82F1

;=======================================================
vModuleStart:	.dw	0
vSongTable:	.dw	0	; song_table
vPatterns:	.dw	0	; patterns
vInstruments:	.dw	0	; instruments
vOrnaments:	.dw	0	; ornaments
vVolumeDelay:	.dw	0	; instrument_delays
vSongTableLoop:	.dw	0

storeNoise:	.dw	0

ptrEnvelopeGenerator:
		.dw	0

;=======================================================
sChannel0:	
		.fill	25
sChannel1:	
		.fill	25
sChannel2:	
		.fill 	25
sChannel3:	
		.fill	25
sChannel4:	
		.fill	25
sChannel5:	
		.fill	25

;=======================================================
Variable:
EAmplitude_ch0:	.db 	0	; + 00h - Amplitude 0 right/left
EAmplitude_ch1:	.db 	0	; + 01h - Amplitude 1 right/left
EAmplitude_ch2:	.db 	0	; + 02h - Amplitude 2 right/left
EAmplitude_ch3:	.db 	0	; + 03h - Amplitude 3 right/left
EAmplitude_ch4:	.db 	0	; + 04h - Amplitude 4 right/left
EAmplitude_ch5:	.db 	0	; + 05h - Amplitude 5 right/left
		.db  	0	; + 06h - XXXX
		.db  	0	; + 07h - XXXX
EFrequency_ch0:	.db 	0	; + 08h - Frequency of tone 0
EFrequency_ch1:	.db	0	; + 09h - Frequency of tone 1
EFrequency_ch2:	.db 	0	; + 0Ah - Frequency of tone 2
EFrequency_ch3:	.db	0	; + 0Bh - Frequency of tone 3
EFrequency_ch4:	.db 	0	; + 0Ch - Frequency of tone 4
EFrequency_ch5:	.db	0	; + 0Dh - Frequency of tone 5
		.db  	0	; + OEh - XXXX	
		.db  	0	; + 0Fh - XXXX
EOctave_ch0:	.db 	0	; + 10h - Octave 1 and 0
EOctave_ch2:	.db 	0	; + 11h - Octave 3 and 2
EOctave_ch4:	.db	0	; + 12h - Octave 5 and 4
		.db  	0	; + 13h - XXXX
EFrequency_en:	.db 	0	; + 14h - Frequency enable
		.db	0	; + 15h - Noise enable
ENoise_gen:	.db 	0	; + 16h - Noise generator 0 and 1
		.db  	0	; + 17h - XXXX
EEnvelope_gen0:	.db  	0	; + 18h - Envelope generator 0 
EEnvelope_gen1:	.db  	0	; + 19h - Envelope generator 1 

vNoise0:	.db 	0	; + 1Ah
vNoise1:	.db 	0	; + 1Bh	

vDelay:		.DB	0	; + 1Ch
vTuneDelay:	.DB	0	; + 1Dh
vDefaultVolumeDelay:
		.DB	0	; + 1Eh
vNoiseGen0:	.DB	0	; + 1Fh
vNoiseGen1:	.DB	0	; + 20h
vNoiseExtended:	.DB	0	; + 21h
vPatternHeight:	.DB	0	; + 22h

.end
