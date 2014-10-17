# Allows arbitrary transforms to be easily applied to hands in the Leap Frame
# This plugin doesn't require THREE.js, but will accept THREE.js Quaternions

# configuration:
# if transform is set, all other properties will be ignored
# transform: a THREE.Matrix4 directly.  This can be either an array of 16-length, or a THREE.matrix4
# quaternion:  a THREE.Quaternion
# position:  a THREE.Vector3
# scale:  a THREE.Vector3 or a number.


Leap.plugin 'transform', (scope = {})->
  noop = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
  _positionTransform = new THREE.Matrix4
  _directionTransform = new THREE.Matrix4


  # no scale
  scope.getDirectionTransform = (hand)->
    if scope.transform
      matrix = if typeof scope.transform == 'function' then scope.transform(hand) else scope.transform

      if window['THREE'] && matrix instanceof THREE.Matrix4
        return matrix.elements
      else
        return matrix

    else if scope.position || scope.quaternion || scope.scale
      _directionTransform.set.apply(_directionTransform, noop)

      if scope.quaternion
        _directionTransform.makeRotationFromQuaternion(
          if typeof scope.quaternion == 'function' then scope.quaternion(hand) else scope.quaternion
        )

      if scope.position
        _directionTransform.setPosition(
          if typeof scope.position == 'function'   then scope.position(hand)   else scope.position
        )

      return _directionTransform.elements

    else
      return noop


  scope.getPositionTransform = (hand)->
    if scope.transform
      matrix = if typeof scope.transform == 'function' then scope.transform(hand) else scope.transform

      if window['THREE'] && matrix instanceof THREE.Matrix4
        return matrix.elements
      else
        return matrix

    else if scope.position || scope.quaternion || scope.scale
      _positionTransform.set.apply(_positionTransform, noop)

      if scope.quaternion
        _positionTransform.makeRotationFromQuaternion(
          if typeof scope.quaternion == 'function' then scope.quaternion(hand) else scope.quaternion
        )

      if scope.scale
        if !isNaN(scope.scale)
          scope.scale = new THREE.Vector3(scope.scale, scope.scale, scope.scale)

        _positionTransform.scale(
          if typeof scope.scale == 'function'      then scope.scale(hand)      else scope.scale
        )

      if scope.position
        _positionTransform.setPosition(
          if typeof scope.position == 'function'   then scope.position(hand)   else scope.position
        )

      return _positionTransform.elements

    else
      return noop



  # implicitly appends 1 to the vec3s, applying both translation and rotation
  transformPositions = (matrix, vec3s...)->
    for vec3 in vec3s
      if vec3 # some recordings may not have all fields
        Leap.vec3.transformMat4(vec3, vec3, matrix)

  transformMat4Implicit0 = (out, a, m) ->
    x = a[0]
    y = a[1]
    z = a[2]

    out[0] = m[0] * x + m[4] * y + m[8]  * z
    out[1] = m[1] * x + m[5] * y + m[9]  * z
    out[2] = m[2] * x + m[6] * y + m[10] * z
    return out

  # appends 0 to the vec3s, applying only rotation
  transformDirections = (matrix, vec3s...)->
    for vec3 in vec3s
      if vec3 # some recordings may not have all fields
        transformMat4Implicit0(vec3, vec3, matrix)


  {
    hand: (hand)->
      positionTransform = scope.getPositionTransform(hand)

      # used for unit vectors, has no scale
      directionTransform = scope.getDirectionTransform(hand)

      transformPositions(
        positionTransform,
        hand.palmPosition,
        hand.stabilizedPalmPosition,
        hand.sphereCenter,
        hand.arm.nextJoint,
        hand.arm.prevJoint
      )

      transformDirections(
        directionTransform,
        hand.direction,
        hand.palmNormal,
        hand.palmVelocity,
        hand.arm.basis[0],
        hand.arm.basis[1],
        hand.arm.basis[2]
      )

      for finger in hand.fingers
        transformPositions(
          positionTransform,
          finger.carpPosition,
          finger.mcpPosition,
          finger.pipPosition,
          finger.dipPosition,
          finger.distal.nextJoint,
          finger.tipPosition
        )
        transformDirections(
          directionTransform,
          finger.direction,
          finger.metacarpal.basis[0],
          finger.metacarpal.basis[1],
          finger.metacarpal.basis[2],
          finger.proximal.basis[0],
          finger.proximal.basis[1],
          finger.proximal.basis[2],
          finger.medial.basis[0],
          finger.medial.basis[1],
          finger.medial.basis[2],
          finger.distal.basis[0],
          finger.distal.basis[1],
          finger.distal.basis[2]
        )

        # recalculate lengths
        len = Leap.vec3.create()
        Leap.vec3.sub(len, finger.mcpPosition, finger.carpPosition)
        finger.metacarpal.length = Leap.vec3.length(len)

        Leap.vec3.sub(len, finger.pipPosition, finger.mcpPosition)
        finger.proximal.length = Leap.vec3.length(len)

        Leap.vec3.sub(len, finger.dipPosition, finger.pipPosition)
        finger.medial.length = Leap.vec3.length(len)

        Leap.vec3.sub(len, finger.tipPosition, finger.dipPosition)
        finger.distal.length = Leap.vec3.length(len)

      Leap.vec3.sub(len, hand.arm.prevJoint, hand.arm.nextJoint)
      hand.arm.length = Leap.vec3.length(len)

  }
