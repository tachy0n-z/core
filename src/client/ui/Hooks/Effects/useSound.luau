
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

-- Modules
local React = require(ReplicatedStorage.Packages.React)

return function(soundId: string, volume: number?, pitch: number?, global: boolean?): { Play: (any) -> () }
    local soundRef = React.useRef(nil :: Sound?)
    local isGlobal = global == true

    -- Create sound if it doesn't exist
    if not soundRef.current then
        if isGlobal then
            local existing = script:FindFirstChild(soundId)
            if existing and existing:IsA("Sound") then
                soundRef.current = existing
            else
                local sound = Instance.new("Sound")
                sound.Name = soundId
                sound.Parent = script
                soundRef.current = sound
            end
        else
            local sound = Instance.new("Sound")
            sound.Name = soundId
            sound.Parent = script
            soundRef.current = sound
        end
    end

    -- Update sound properties when they change
    React.useEffect(function(): () -> ()
        local sound = soundRef.current
        if sound then
            sound.Name = soundId
            sound.SoundId = soundId
            sound.Volume = volume or 1
            sound.PlaybackSpeed = pitch or 1
        end

        return function(): ()
            if not isGlobal and soundRef.current then
                soundRef.current:Destroy()
                soundRef.current = nil
            end
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