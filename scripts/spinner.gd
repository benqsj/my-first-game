class_name Spinner
extends Node3D

## Turns whatever hangs off it, slowly and forever.
##
## For the windmill's sails, and for anything else whose whole job is to not be
## standing still. Deliberately not physics and deliberately not networked: it is
## a function of the clock, so every peer sees the same sails in the same place
## without a word being said about it, and a frame that drops changes nothing.

## Axis turned about, in the node's own frame. The kit's sails face down their
## local -Z, so they turn about that.
@export var axis: Vector3 = Vector3.BACK
## Turns per minute. A mill sail is slow — much above ten and it reads as a fan.
@export var rpm: float = 3.5
## Gusts: the rate wanders by this fraction of `rpm`, over `gust_period` seconds,
## so the sails are not a metronome.
@export var gust: float = 0.35
@export var gust_period: float = 11.0
## Offset into the gust cycle, so two mills on one map are not in step.
@export var phase: float = 0.0

var _axis: Vector3 = Vector3.BACK
var _time: float = 0.0


func _ready() -> void:
	_axis = axis.normalized() if not axis.is_zero_approx() else Vector3.BACK
	# Started from the clock rather than from zero, so a mill that comes into
	# view is already part-way round rather than snapping to its rest position.
	_time = phase


func _process(delta: float) -> void:
	_time += delta
	var swell := 1.0 + gust * sin(TAU * _time / maxf(gust_period, 0.01))
	rotate(_axis, TAU * rpm / 60.0 * swell * delta)
