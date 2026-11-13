
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

-- Modules
local React = require(ReplicatedStorage.Packages.React)

-- State
local globalSounds: {[string]: Sound} = {}

return function(soundId: string, volume: number?, pitch: number?, global: boolean?): { Play: (any) -> () }
    local soundRef = React.useRef(nil :: Sound?)
    local isGlobal = global == true

    -- Create sound (or reuse the shared one if global), before any effect can play it
    React.useLayoutEffect(function(): () -> ()
        local existing = if isGlobal then globalSounds[soundId] else nil
        local sound: Sound
        if existing then
            sound = existing
        else
            sound = Instance.new("Sound")
            sound.Name = soundId
            sound.SoundId = soundId
            sound.Parent = script
            if isGlobal then
                globalSounds[soundId] = sound
            end
        end
        soundRef.current = sound

        return function(): ()
            soundRef.current = nil
            if not isGlobal then
                sound:Destroy()
            end
        end
    end, { soundId, isGlobal } :: {any})

    -- Update sound properties when they change
    React.useLayoutEffect(function(): ()
        local sound = soundRef.current
        if sound then
            sound.Volume = volume or 1
            sound.PlaybackSpeed = pitch or 1
        end
    end, { soundId, volume, pitch, isGlobal } :: {any})

    return {
        Play = function(): ()
            local sound = soundRef.current
            if sound then
                if RunService:IsRunning() then
                    sound:Play()
                else
                    SoundService:PlayLocalSound(sound)
                end
            end
        end
    }
end