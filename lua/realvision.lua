local function InitializeConVars()
    CreateClientConVar("realvision_enabled", "0", true, true)
    CreateClientConVar("realvision_attachment", "eyes", false, true)
    CreateClientConVar("realvision_eyedistance", "6", true, true) -- Distance between eyes

    -- New ConVars for eye position and rotation
    CreateClientConVar("realvision_left_eye_x", "0", true, true)
    CreateClientConVar("realvision_left_eye_y", "0", true, true)
    CreateClientConVar("realvision_left_eye_z", "0", true, true)
    CreateClientConVar("realvision_right_eye_x", "0", true, true)
    CreateClientConVar("realvision_right_eye_y", "0", true, true)
    CreateClientConVar("realvision_right_eye_z", "0", true, true)

    CreateClientConVar("realvision_left_eye_pitch", "0", true, true)
    CreateClientConVar("realvision_left_eye_yaw", "0", true, true)
    CreateClientConVar("realvision_left_eye_roll", "0", true, true)
    CreateClientConVar("realvision_right_eye_pitch", "0", true, true)
    CreateClientConVar("realvision_right_eye_yaw", "0", true, true)
    CreateClientConVar("realvision_right_eye_roll", "0", true, true)

    CreateClientConVar("realvision_default_camera_toggle", "0", true, true)

    -- New ConVars for convergence/divergence and focal distance
    CreateClientConVar("realvision_convergence_divergence", "0", true, true)
    CreateClientConVar("realvision_focal_distance", "0", true, true)

    -- New ConVars for eye rotation sliders
    CreateClientConVar("realvision_eye_rotation_x", "0", true, true)
    CreateClientConVar("realvision_eye_rotation_y", "0", true, true)
    CreateClientConVar("realvision_eye_rotation_z", "0", true, true)

    -- New ConVars for FOV
    CreateClientConVar("realvision_fov", "90", true, true)

    -- New ConVars for Eye Trucking Controls
    CreateClientConVar("realvision_truck_x", "0", true, true)
    CreateClientConVar("realvision_truck_y", "0", true, true)
    CreateClientConVar("realvision_truck_z", "0", true, true)

    -- New ConVars for model visibility
    CreateClientConVar("realvision_show_left_eye_model", "1", true, true)
    CreateClientConVar("realvision_show_right_eye_model", "1", true, true)
    CreateClientConVar("realvision_show_default_model", "1", true, true)
    CreateClientConVar("realvision_show_head", "1", true, true)
end

local function REALVISION_Initialize()
    if CLIENT then
        InitializeConVars()
    end
end
hook.Add("Initialize", "REALVISION_Initialize", REALVISION_Initialize)

local function REALVISION_Think()
    if CLIENT then
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
    end
end
hook.Add("Think", "REALVISION_Think", REALVISION_Think)

if CLIENT then
    local leftEyeRT = GetRenderTarget("RealVision_LeftEyeRT", ScrW() / 2, ScrH(), false)
    local rightEyeRT = GetRenderTarget("RealVision_RightEyeRT", ScrW() / 2, ScrH(), false)

    local leftEyeMaterial = CreateMaterial("RealVision_LeftEyeMat", "UnlitGeneric", {
        ["$basetexture"] = leftEyeRT:GetName(),
        ["$translucent"] = 1
    })

    local rightEyeMaterial = CreateMaterial("RealVision_RightEyeMat", "UnlitGeneric", {
        ["$basetexture"] = rightEyeRT:GetName(),
        ["$translucent"] = 1
    })

    local function GetEyePositions(ply)
        -- Use the default "eyes" attachment
        local eyesAttachment = ply:LookupAttachment("eyes")
        if eyesAttachment <= 0 then
            print("[RealVision] Error: Failed to find 'eyes' attachment.")
            return Vector(0, 0, 0), Vector(0, 0, 0)
        end

        local eyesData = ply:GetAttachment(eyesAttachment)
        if not eyesData then
            print("[RealVision] Error: Invalid 'eyes' attachment data.")
            return Vector(0, 0, 0), Vector(0, 0, 0)
        end

        local eyePos = eyesData.Pos or Vector(0, 0, 0)
        local eyeAngles = ply:EyeAngles()

        -- Calculate eye positions by offsetting from the center based on the eye distance
        local eyeDistance = GetConVar("realvision_eyedistance"):GetFloat()
        local rightEyeOffset = eyeAngles:Right() * (eyeDistance / 2)
        local leftEyeOffset = eyeAngles:Right() * -(eyeDistance / 2)

        local leftEyePos = eyePos + leftEyeOffset
        local rightEyePos = eyePos + rightEyeOffset

        -- Apply independent eye position controls
        leftEyePos = leftEyePos + Vector(GetConVar("realvision_left_eye_x"):GetFloat(), GetConVar("realvision_left_eye_y"):GetFloat(), GetConVar("realvision_left_eye_z"):GetFloat())
        rightEyePos = rightEyePos + Vector(GetConVar("realvision_right_eye_x"):GetFloat(), GetConVar("realvision_right_eye_y"):GetFloat(), GetConVar("realvision_right_eye_z"):GetFloat())

        -- Apply Eye Trucking Controls
        local truckX = GetConVar("realvision_truck_x"):GetFloat()
        local truckY = GetConVar("realvision_truck_y"):GetFloat()
        local truckZ = GetConVar("realvision_truck_z"):GetFloat()
        leftEyePos = leftEyePos + Vector(truckX, truckY, truckZ)
        rightEyePos = rightEyePos + Vector(truckX, truckY, truckZ)

        return leftEyePos, rightEyePos
    end

    local function REALVISION_RenderScene()
        local ply = LocalPlayer()
        if not GetConVar("realvision_enabled"):GetBool() or not IsValid(ply) or not ply:Alive() then return end

        -- Clear the screen before rendering the RT cameras
        render.Clear(0, 0, 0, 255)

        local leftEyePos, rightEyePos = GetEyePositions(ply)
        if not leftEyePos or not rightEyePos then return end

        local eyeAngles = ply:EyeAngles()
        local w, h = ScrW(), ScrH()

        -- Apply convergence/divergence
        local convergenceDivergence = GetConVar("realvision_convergence_divergence"):GetFloat()
        local convergenceAngle = Angle(0, convergenceDivergence, 0)

        -- Apply eye rotation sliders
        local eyeRotationX = GetConVar("realvision_eye_rotation_x"):GetFloat()
        local eyeRotationY = GetConVar("realvision_eye_rotation_y"):GetFloat()
        local eyeRotationZ = GetConVar("realvision_eye_rotation_z"):GetFloat()
        local eyeRotation = Angle(eyeRotationX, eyeRotationY, eyeRotationZ)

        -- Apply focal distance
        local focalDistance = GetConVar("realvision_focal_distance"):GetFloat()
        local focalOffset = Vector(0, 0, focalDistance)

        -- Render left eye view
        if GetConVar("realvision_show_left_eye_model"):GetBool() then
            render.PushRenderTarget(leftEyeRT)
            render.RenderView({
                origin = leftEyePos + focalOffset,
                angles = eyeAngles + convergenceAngle + eyeRotation + Angle(GetConVar("realvision_left_eye_pitch"):GetFloat(), GetConVar("realvision_left_eye_yaw"):GetFloat(), GetConVar("realvision_left_eye_roll"):GetFloat()),
                x = 0, y = 0,
                w = w / 2, h = h,
                fov = GetConVar("realvision_fov"):GetFloat()
            })
            render.PopRenderTarget()
        end

        -- Render right eye view
        if GetConVar("realvision_show_right_eye_model"):GetBool() then
            render.PushRenderTarget(rightEyeRT)
            render.RenderView({
                origin = rightEyePos + focalOffset,
                angles = eyeAngles - convergenceAngle + eyeRotation + Angle(GetConVar("realvision_right_eye_pitch"):GetFloat(), GetConVar("realvision_right_eye_yaw"):GetFloat(), GetConVar("realvision_right_eye_roll"):GetFloat()),
                x = 0, y = 0,
                w = w / 2, h = h,
                fov = GetConVar("realvision_fov"):GetFloat()
            })
            render.PopRenderTarget()
        end
    end
    hook.Add("RenderScene", "REALVISION_RenderScene", REALVISION_RenderScene)

    local function REALVISION_HUDPaint()
        local ply = LocalPlayer()
        if not GetConVar("realvision_enabled"):GetBool() or not IsValid(ply) or not ply:Alive() then return end

        local w, h = ScrW(), ScrH()

        -- Draw left eye view
        if GetConVar("realvision_show_left_eye_model"):GetBool() then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(leftEyeMaterial)
            surface.DrawTexturedRect(0, 0, w / 2, h)
        end

        -- Draw right eye view
        if GetConVar("realvision_show_right_eye_model"):GetBool() then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(rightEyeMaterial)
            surface.DrawTexturedRect(w / 2, 0, w / 2, h)
        end

        -- Draw debug text
        draw.SimpleText("Left Eye", "DermaDefault", w * 0.25, h * 0.5, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Right Eye", "DermaDefault", w * 0.75, h * 0.5, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    hook.Add("HUDPaint", "REALVISION_HUDPaint", REALVISION_HUDPaint)

    local function REALVISION_CalcView(ply, origin, angles, fov, znear, zfar)
        if not GetConVar("realvision_enabled"):GetBool() or not IsValid(ply) or not ply:Alive() then
            return
        end

        if GetConVar("realvision_default_camera_toggle"):GetBool() then
            return {
                origin = origin,
                angles = angles,
                fov = fov
            }
        end

        -- Disable the main camera/view when RT cameras are in use
        return nil
    end
    hook.Add("CalcView", "REALVISION_CalcView", REALVISION_CalcView)

    -- Utility menu for RealVision settings
    local function REALVISION_Menu()
        local frame = vgui.Create("DFrame")
        frame:SetSize(800, 900)
        frame:SetTitle("RealVision Settings")
        frame:Center()
        frame:MakePopup()

        local enabledCheckbox = vgui.Create("DCheckBoxLabel", frame)
        enabledCheckbox:SetPos(10, 30)
        enabledCheckbox:SetText("Enable RealVision")
        enabledCheckbox:SetConVar("realvision_enabled")
        enabledCheckbox:SizeToContents()

        local attachmentLabel = vgui.Create("DLabel", frame)
        attachmentLabel:SetPos(10, 60)
        attachmentLabel:SetText("Attachment:")
        attachmentLabel:SizeToContents()

        local attachmentTextEntry = vgui.Create("DTextEntry", frame)
        attachmentTextEntry:SetPos(10, 80)
        attachmentTextEntry:SetSize(100, 20)
        attachmentTextEntry:SetConVar("realvision_attachment")

        local eyeDistanceSlider = vgui.Create("DNumSlider", frame)
        eyeDistanceSlider:SetPos(10, 110)
        eyeDistanceSlider:SetSize(380, 20)
        eyeDistanceSlider:SetText("Eye Distance")
        eyeDistanceSlider:SetMin(-200)
        eyeDistanceSlider:SetMax(200)
        eyeDistanceSlider:SetDecimals(2)
        eyeDistanceSlider:SetConVar("realvision_eyedistance")

        -- Left Eye Position Controls
        local leftEyeXSlider = vgui.Create("DNumSlider", frame)
        leftEyeXSlider:SetPos(10, 140)
        leftEyeXSlider:SetSize(380, 20)
        leftEyeXSlider:SetText("Left Eye X Position")
        leftEyeXSlider:SetMin(-10)
        leftEyeXSlider:SetMax(10)
        leftEyeXSlider:SetDecimals(2)
        leftEyeXSlider:SetConVar("realvision_left_eye_x")

        local leftEyeYSlider = vgui.Create("DNumSlider", frame)
        leftEyeYSlider:SetPos(10, 170)
        leftEyeYSlider:SetSize(380, 20)
        leftEyeYSlider:SetText("Left Eye Y Position")
        leftEyeYSlider:SetMin(-10)
        leftEyeYSlider:SetMax(10)
        leftEyeYSlider:SetDecimals(2)
        leftEyeYSlider:SetConVar("realvision_left_eye_y")

        local leftEyeZSlider = vgui.Create("DNumSlider", frame)
        leftEyeZSlider:SetPos(10, 200)
        leftEyeZSlider:SetSize(380, 20)
        leftEyeZSlider:SetText("Left Eye Z Position")
        leftEyeZSlider:SetMin(-10)
        leftEyeZSlider:SetMax(10)
        leftEyeZSlider:SetDecimals(2)
        leftEyeZSlider:SetConVar("realvision_left_eye_z")

        -- Right Eye Position Controls
        local rightEyeXSlider = vgui.Create("DNumSlider", frame)
        rightEyeXSlider:SetPos(10, 230)
        rightEyeXSlider:SetSize(380, 20)
        rightEyeXSlider:SetText("Right Eye X Position")
        rightEyeXSlider:SetMin(-10)
        rightEyeXSlider:SetMax(10)
        rightEyeXSlider:SetDecimals(2)
        rightEyeXSlider:SetConVar("realvision_right_eye_x")

        local rightEyeYSlider = vgui.Create("DNumSlider", frame)
        rightEyeYSlider:SetPos(10, 260)
        rightEyeYSlider:SetSize(380, 20)
        rightEyeYSlider:SetText("Right Eye Y Position")
        rightEyeYSlider:SetMin(-10)
        rightEyeYSlider:SetMax(10)
        rightEyeYSlider:SetDecimals(2)
        rightEyeYSlider:SetConVar("realvision_right_eye_y")

        local rightEyeZSlider = vgui.Create("DNumSlider", frame)
        rightEyeZSlider:SetPos(10, 290)
        rightEyeZSlider:SetSize(380, 20)
        rightEyeZSlider:SetText("Right Eye Z Position")
        rightEyeZSlider:SetMin(-10)
        rightEyeZSlider:SetMax(10)
        rightEyeZSlider:SetDecimals(2)
        rightEyeZSlider:SetConVar("realvision_right_eye_z")

        -- Left Eye Rotation Controls
        local leftEyePitchSlider = vgui.Create("DNumSlider", frame)
        leftEyePitchSlider:SetPos(10, 320)
        leftEyePitchSlider:SetSize(380, 20)
        leftEyePitchSlider:SetText("Left Eye Pitch (X-Axis)")
        leftEyePitchSlider:SetMin(-90)
        leftEyePitchSlider:SetMax(90)
        leftEyePitchSlider:SetDecimals(2)
        leftEyePitchSlider:SetConVar("realvision_left_eye_pitch")

        local leftEyeYawSlider = vgui.Create("DNumSlider", frame)
        leftEyeYawSlider:SetPos(10, 350)
        leftEyeYawSlider:SetSize(380, 20)
        leftEyeYawSlider:SetText("Left Eye Yaw (Y-Axis)")
        leftEyeYawSlider:SetMin(-90)
        leftEyeYawSlider:SetMax(90)
        leftEyeYawSlider:SetDecimals(2)
        leftEyeYawSlider:SetConVar("realvision_left_eye_yaw")

        local leftEyeRollSlider = vgui.Create("DNumSlider", frame)
        leftEyeRollSlider:SetPos(10, 380)
        leftEyeRollSlider:SetSize(380, 20)
        leftEyeRollSlider:SetText("Left Eye Roll (Z-Axis)")
        leftEyeRollSlider:SetMin(-180)
        leftEyeRollSlider:SetMax(180)
        leftEyeRollSlider:SetDecimals(2)
        leftEyeRollSlider:SetConVar("realvision_left_eye_roll")

        -- Right Eye Rotation Controls
        local rightEyePitchSlider = vgui.Create("DNumSlider", frame)
        rightEyePitchSlider:SetPos(10, 410)
        rightEyePitchSlider:SetSize(380, 20)
        rightEyePitchSlider:SetText("Right Eye Pitch (X-Axis)")
        rightEyePitchSlider:SetMin(-90)
        rightEyePitchSlider:SetMax(90)
        rightEyePitchSlider:SetDecimals(2)
        rightEyePitchSlider:SetConVar("realvision_right_eye_pitch")

        local rightEyeYawSlider = vgui.Create("DNumSlider", frame)
        rightEyeYawSlider:SetPos(10, 440)
        rightEyeYawSlider:SetSize(380, 20)
        rightEyeYawSlider:SetText("Right Eye Yaw (Y-Axis)")
        rightEyeYawSlider:SetMin(-90)
        rightEyeYawSlider:SetMax(90)
        rightEyeYawSlider:SetDecimals(2)
        rightEyeYawSlider:SetConVar("realvision_right_eye_yaw")

        local rightEyeRollSlider = vgui.Create("DNumSlider", frame)
        rightEyeRollSlider:SetPos(10, 470)
        rightEyeRollSlider:SetSize(380, 20)
        rightEyeRollSlider:SetText("Right Eye Roll (Z-Axis)")
        rightEyeRollSlider:SetMin(-180)
        rightEyeRollSlider:SetMax(180)
        rightEyeRollSlider:SetDecimals(2)
        rightEyeRollSlider:SetConVar("realvision_right_eye_roll")

        -- Default Camera Toggle
        local defaultCameraCheckbox = vgui.Create("DCheckBoxLabel", frame)
        defaultCameraCheckbox:SetPos(10, 500)
        defaultCameraCheckbox:SetText("Default Camera Toggle")
        defaultCameraCheckbox:SetConVar("realvision_default_camera_toggle")
        defaultCameraCheckbox:SizeToContents()

        -- Convergence/Divergence Controls
        local convergenceDivergenceSlider = vgui.Create("DNumSlider", frame)
        convergenceDivergenceSlider:SetPos(10, 530)
        convergenceDivergenceSlider:SetSize(380, 20)
        convergenceDivergenceSlider:SetText("Convergence/Divergence")
        convergenceDivergenceSlider:SetMin(-90)
        convergenceDivergenceSlider:SetMax(90)
        convergenceDivergenceSlider:SetDecimals(2)
        convergenceDivergenceSlider:SetConVar("realvision_convergence_divergence")

        local focalDistanceTextEntry = vgui.Create("DTextEntry", frame)
        focalDistanceTextEntry:SetPos(10, 560)
        focalDistanceTextEntry:SetSize(100, 20)
        focalDistanceTextEntry:SetConVar("realvision_focal_distance")

        local focalDistanceLabel = vgui.Create("DLabel", frame)
        focalDistanceLabel:SetPos(120, 560)
        focalDistanceLabel:SetText("Focal Distance")
        focalDistanceLabel:SizeToContents()

        -- Eye Rotation Sliders
        local eyeRotationXSlider = vgui.Create("DNumSlider", frame)
        eyeRotationXSlider:SetPos(10, 590)
        eyeRotationXSlider:SetSize(380, 20)
        eyeRotationXSlider:SetText("Eye Rotation X")
        eyeRotationXSlider:SetMin(-180)
        eyeRotationXSlider:SetMax(180)
        eyeRotationXSlider:SetDecimals(2)
        eyeRotationXSlider:SetConVar("realvision_eye_rotation_x")

        local eyeRotationYSlider = vgui.Create("DNumSlider", frame)
        eyeRotationYSlider:SetPos(10, 620)
        eyeRotationYSlider:SetSize(380, 20)
        eyeRotationYSlider:SetText("Eye Rotation Y")
        eyeRotationYSlider:SetMin(-180)
        eyeRotationYSlider:SetMax(180)
        eyeRotationYSlider:SetDecimals(2)
        eyeRotationYSlider:SetConVar("realvision_eye_rotation_y")

        local eyeRotationZSlider = vgui.Create("DNumSlider", frame)
        eyeRotationZSlider:SetPos(10, 650)
        eyeRotationZSlider:SetSize(380, 20)
        eyeRotationZSlider:SetText("Eye Rotation Z")
        eyeRotationZSlider:SetMin(-180)
        eyeRotationZSlider:SetMax(180)
        eyeRotationZSlider:SetDecimals(2)
        eyeRotationZSlider:SetConVar("realvision_eye_rotation_z")

        -- FOV Slider
        local fovSlider = vgui.Create("DNumSlider", frame)
        fovSlider:SetPos(10, 680)
        fovSlider:SetSize(380, 20)
        fovSlider:SetText("Field of View (FOV)")
        fovSlider:SetMin(0)
        fovSlider:SetMax(360)
        fovSlider:SetDecimals(2)
        fovSlider:SetConVar("realvision_fov")

        -- Eye Trucking Controls
        local truckXSlider = vgui.Create("DNumSlider", frame)
        truckXSlider:SetPos(10, 710)
        truckXSlider:SetSize(380, 20)
        truckXSlider:SetText("Truck X (Horizontal)")
        truckXSlider:SetMin(-10)
        truckXSlider:SetMax(10)
        truckXSlider:SetDecimals(2)
        truckXSlider:SetConVar("realvision_truck_x")

        local truckYSlider = vgui.Create("DNumSlider", frame)
        truckYSlider:SetPos(10, 740)
        truckYSlider:SetSize(380, 20)
        truckYSlider:SetText("Truck Y (Vertical)")
        truckYSlider:SetMin(-10)
        truckYSlider:SetMax(10)
        truckYSlider:SetDecimals(2)
        truckYSlider:SetConVar("realvision_truck_y")

        local truckZSlider = vgui.Create("DNumSlider", frame)
        truckZSlider:SetPos(10, 770)
        truckZSlider:SetSize(380, 20)
        truckZSlider:SetText("Truck Z (Depth)")
        truckZSlider:SetMin(-10)
        truckZSlider:SetMax(10)
        truckZSlider:SetDecimals(2)
        truckZSlider:SetConVar("realvision_truck_z")

        -- Model Visibility Checkboxes
        local showLeftEyeModelCheckbox = vgui.Create("DCheckBoxLabel", frame)
        showLeftEyeModelCheckbox:SetPos(400, 30)
        showLeftEyeModelCheckbox:SetText("Show Left Eye Model")
        showLeftEyeModelCheckbox:SetConVar("realvision_show_left_eye_model")
        showLeftEyeModelCheckbox:SizeToContents()

        local showRightEyeModelCheckbox = vgui.Create("DCheckBoxLabel", frame)
        showRightEyeModelCheckbox:SetPos(400, 60)
        showRightEyeModelCheckbox:SetText("Show Right Eye Model")
        showRightEyeModelCheckbox:SetConVar("realvision_show_right_eye_model")
        showRightEyeModelCheckbox:SizeToContents()

        local showDefaultModelCheckbox = vgui.Create("DCheckBoxLabel", frame)
        showDefaultModelCheckbox:SetPos(400, 90)
        showDefaultModelCheckbox:SetText("Show Default Model")
        showDefaultModelCheckbox:SetConVar("realvision_show_default_model")
        showDefaultModelCheckbox:SizeToContents()

        -- Show Head Checkbox
        local showHeadCheckbox = vgui.Create("DCheckBoxLabel", frame)
        showHeadCheckbox:SetPos(400, 120)
        showHeadCheckbox:SetText("Show Head")
        showHeadCheckbox:SetConVar("realvision_show_head")
        showHeadCheckbox:SizeToContents()

        -- Reset Button
        local resetButton = vgui.Create("DButton", frame)
        resetButton:SetPos(10, 860)
        resetButton:SetSize(100, 20)
        resetButton:SetText("Reset All")
        resetButton.DoClick = function()
            RunConsoleCommand("realvision_enabled", "0")
            RunConsoleCommand("realvision_attachment", "eyes")
            RunConsoleCommand("realvision_eyedistance", "6")
            RunConsoleCommand("realvision_left_eye_x", "0")
            RunConsoleCommand("realvision_left_eye_y", "0")
            RunConsoleCommand("realvision_left_eye_z", "0")
            RunConsoleCommand("realvision_right_eye_x", "0")
            RunConsoleCommand("realvision_right_eye_y", "0")
            RunConsoleCommand("realvision_right_eye_z", "0")
            RunConsoleCommand("realvision_left_eye_pitch", "0")
            RunConsoleCommand("realvision_left_eye_yaw", "0")
            RunConsoleCommand("realvision_left_eye_roll", "0")
            RunConsoleCommand("realvision_right_eye_pitch", "0")
            RunConsoleCommand("realvision_right_eye_yaw", "0")
            RunConsoleCommand("realvision_right_eye_roll", "0")
            RunConsoleCommand("realvision_default_camera_toggle", "0")
            RunConsoleCommand("realvision_convergence_divergence", "0")
            RunConsoleCommand("realvision_focal_distance", "0")
            RunConsoleCommand("realvision_eye_rotation_x", "0")
            RunConsoleCommand("realvision_eye_rotation_y", "0")
            RunConsoleCommand("realvision_eye_rotation_z", "0")
            RunConsoleCommand("realvision_fov", "90")
            RunConsoleCommand("realvision_truck_x", "0")
            RunConsoleCommand("realvision_truck_y", "0")
            RunConsoleCommand("realvision_truck_z", "0")
            RunConsoleCommand("realvision_show_left_eye_model", "1")
            RunConsoleCommand("realvision_show_right_eye_model", "1")
            RunConsoleCommand("realvision_show_default_model", "1")
            RunConsoleCommand("realvision_show_head", "1")
        end
    end

    concommand.Add("realvision_menu", REALVISION_Menu)

    -- Function to toggle model visibility
    local function ToggleModelVisibility(ply)
        if not IsValid(ply) then return end

        local showDefaultModel = GetConVar("realvision_show_default_model"):GetBool()
        local showHead = GetConVar("realvision_show_head"):GetBool()

        if showDefaultModel then
            ply:SetNoDraw(false)
        else
            ply:SetNoDraw(true)
        end

        if showHead then
            ply:ManipulateBoneScale(ply:LookupBone("ValveBiped.Bip01_Head1"), Vector(1, 1, 1))
        else
            ply:ManipulateBoneScale(ply:LookupBone("ValveBiped.Bip01_Head1"), Vector(0, 0, 0))
        end
    end

    hook.Add("PreRender", "REALVISION_ToggleModelVisibility", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        ToggleModelVisibility(ply)
    end)
end

-- Bind the realvision_menu command to a key
hook.Add("PlayerButtonDown", "OpenRealVisionMenu", function(ply, button)
    if button == KEY_F1 then -- Change KEY_F1 to the desired key
        RunConsoleCommand("realvision_menu")
    end
end)
 
