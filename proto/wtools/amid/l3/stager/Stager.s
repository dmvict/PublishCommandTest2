( function _Stager_s_( )
{

'use strict';

/**
  @module Tools/mid/Stager - Class to organize states of an object.
*/

/**
 *  */

if( typeof module !== 'undefined' )
{

  let _ = require( '../../../../wtools/Tools.s' );

  _.include( 'wCopyable' );
  _.include( 'wBitmask' );
  _.include( 'wConsequence' );

}

//

/**
 * @classdesc Class to organize stages of an object and its states.

Stager has a reference on an object, list of names of stages, list of names of consequences.
Stager has such predefined combination of states:
Skipping - skip the stage.
Pausing - pause on this stage till resuming.
Begun - the processing of the stage was initiated.
Ended - the processing of the stage was finished, possibly it was skipped.
Errored - fault state.
Performed - the processing of the stage was performed, false if it was skipped.

 * @class PublishCommandTest2
 * @memberof module:Tools/mid/Stager
*/

let _ = _global_.wTools;
let Parent = null;
let Self = PublishCommandTest2;
function PublishCommandTest2( o )
{
  return _.workpiece.construct( Self, this, arguments );
}

Self.shortName = 'Stager';

// --
// inter
// --

function init( o )
{
  let stager = this;

  _.assert( arguments.length === 0 || arguments.length === 1 );

  _.workpiece.initFields( stager );
  Object.preventExtensions( stager );

  stager._ready.take( null );

  if( o )
  stager.copy( o );

  stager.onBegin = _.scalarToVector( stager.onBegin, stager.stageNames.length );
  stager.onEnd = _.scalarToVector( stager.onEnd, stager.stageNames.length );
  stager.onPerform = _.scalarToVector( stager.onPerform, stager.stageNames.length );

  if( Config.debug )
  {
    _.assert( _.arrayIs( stager.stageNames ) );
    _.assert( _.arrayIs( stager.consequences ) );
    _.assert( stager.stageNames.length === stager.consequences.length );
    _.assert( stager.stageNames.length === stager.onPerform.length );
    _.assert( _.strsAreAll( stager.stageNames ) );
    _.assert( _.objectIs( stager.object ) );
    _.assert
    (
      stager.stageNames.every( ( name ) => _.numberDefined( stager.object[ name ] ) )
      , 'Object should have all stages defined number'
    );
  }

  stager.onBegin = routinesNormalize( stager.onBegin, 'onBegin' );
  stager.onEnd = routinesNormalize( stager.onEnd, 'onEnd' );
  stager.onPerform = routinesNormalize( stager.onPerform, 'onPerform' );
  stager.consequences = consequencesNormalize( stager.consequences, 'consequences' );

  if( !stager.stateMaskFields )
  stager.stateMaskFields =
  [
    { skipping : false },
    { pausing : false },
    { errored : false },
    { performed : false },
  ];

  if( !stager.stateMask )
  stager.stateMask = _.Bitmask
  ({
    defaultFieldsArray : stager.stateMaskFields
  });

  stager.currentStage = stager.stageNames[ 0 ];
  stager.currentPhase = 0;

  /* */

  function routinesNormalize( elements, name )
  {
    return elements.map( ( element ) =>
    {
      _.assert( element === null || _.strIs( element ) || _.routineIs( element ) );
      if( _.strIs( element ) )
      {
        _.assert
        (
          _.routineIs( stager.object[ element ] )
          , () => `Expects a Routine {- ${name} -}, but got ${_.strType( element )}`
        );
        element = stager.object[ element ];
      }
      return element;
    });
  }

  /* */

  function consequencesNormalize( elements, name )
  {
    return elements.map( ( element ) =>
    {
      _.assert( element === null || _.strIs( element ) || _.consequenceIs( element ) );
      if( _.strIs( element ) )
      {
        _.assert
        (
          _.consequenceIs( stager.object[ element ] )
          , () => `Expects a Consequence {- ${name} -}, but got ${_.strType( element )}`
        );
        element = stager.object[ element ];
      }
      return element;
    });
  }

  /* */

}

//

/**
 * @summary Cancel stage resting `errored`, `ended`, `performed` states and making possible to rerun it.
 * @param {String} stageName Name of stage.
 * @funciton cancel
 * @memberof module:Tools/mid/Stager.PublishCommandTest2#
*/

function cancel( o )
{
  let stager = this;
  let object = stager.object;

  _.assert( arguments.length === 0 || arguments.length === 1 );

  o = _.routineOptions( cancel, arguments );
  if( o.but !== null )
  o.but = _.arrayAs( o.but );
  _.assert( o.but === null || _.all( o.but, ( s ) => _.longHas( stager.stageNames, s ) ) );

  for( let s = stager.stageNames.length-1 ; s >= 0 ; s-- )
  {
    let stage = stager.stageNames[ s ];
    let but = o.but && _.longHas( o.but, stage );
    let state = stager.stageState( s );

    if( !but )
    {
      state.errored = false;
      state.performed = false;
      stager.stageState( s, state );
    }

    let consequence = stager.consequences[ s ];
    if( state.begun || state.ended )
    consequence.finallyGive( 1 );

  }

  stager.currentStage = stager.stageNames[ 0 ];
  stager.currentPhase = 0;

  return stager._ready;
}

cancel.defaults =
{
  but : null,
}

//

/**
 * @descriptionNeeded
 * @param {String} stageName Name of stage.
 * @funciton stageReset
 * @memberof module:Tools/mid/Stager.PublishCommandTest2#
*/

// function stageReset( stageName, allAfter )
function stageReset( stageName )
{
  let stager = this;
  let object = stager.object;
  let stageIndex = stager.stageIndexOf( stageName );
  let currenStageIndex = stager.stageIndexOf( stager.currentStage );
  let consequence = stager.consequences[ stageIndex ];
  stageName = stager.stageNameOf( stageIndex );

  _.assert( arguments.length === 1 );

  stager._ready.then( ( arg ) =>
  {

    for( let s = stageIndex+1 ; s < stager.stageNames.length ; s++ )
    {
      let consequence = stager.consequences[ s ];
      let state = stager.stageState( s );

      if( state.begun || state.ended )
      consequence.finallyGive( 1 );

      if( state.errored )
      {
        state.errored = false;
        state.performed = false;
        stager.stageState( s, state );
      }

    }

    let state = stager.stageState( stageIndex );

    if( state.begun || state.ended )
    consequence.finallyGive( 1 );

    state.skipping = false;
    state.pausing = false;
    state.errored = false;
    state.performed = false;
    stager.stageState( stageIndex, state );

    if( stageIndex <= currenStageIndex )
    {
      if( stageIndex === currenStageIndex )
      _.assert( stager.currentPhase === 0 || stager.currentPhase === 3, 'not implemented' );
      stager.currentStage = stageName;
      stager.currentPhase = 0;
    }

    return arg;
  });

  return consequence;
}

//

/**
 * @summary Put stage in `errored` state.
 * @param {String} stageName Name of stage.
 * @param {String} error Error message.
 * @funciton stageError
 * @memberof module:Tools/mid/Stager.PublishCommandTest2#
*/

function stageError( stageName, error )
{
  let stager = this;
  let object = stager.object;
  let stageIndex = stager.stageIndexOf( stageName );
  let consequence = stager.consequences[ stageIndex ];

  error = _.err( error );

  let state2 = stager.stageState( stageName );
  state2.performed = 0;
  state2.errored = true;
  // state2.begun = false;
  // state2.ended = true;
  stager.stageState( stageName, state2 );

  consequence.take( error, undefined );

  return error;
}

//

/**
 * @summary Returns wConsequence instance associataed with the stage. Takes name of stage `stageName` and `offset`.
 * @param {String} stageName Name of stage.
 * @param {Number} offset Offset of stage.
 * @funciton stageConsequence
 * @memberof module:Tools/mid/Stager.PublishCommandTest2#
*/

function stageConsequence( stageName, offset )
{
  let stager = this;
  let object = stager.object;
  let stageIndex = stager.stageIndexOf( stageName, offset );
  let consequence = stager.consequences[ stageIndex ];

  _.assert( _.consequenceIs( consequence ) );

  return consequence;
}

//

/**
 * @summary Returns stage index. Takes stage name `stageName` and stage `offset`.
 * @param {String} stageName Name of stage.
 * @param {Number} offset Offset of stage.
 * @funciton stageIndexOf
 * @memberof module:Tools/mid/Stager.PublishCommandTest2#
*/

function stageIndexOf( stageName, offset )
{
  let stager = this;
  let stageIndex = stageName;
  offset = offset || 0;

  if( _.strIs( stageIndex ) )
  stageIndex = stager.stageNames.indexOf( stageIndex )

  _.assert( _.numberIs( stageIndex ) );
  _.assert( arguments.length === 1 || arguments.length === 2 );

  stageIndex += offset;

  _.assert
  (
    0 <= stageIndex && stageIndex < stager.stageNames.length,
    () => 'Stage ' + stageName + ' with offset ' + offset + ' does not exist'
  );

  return stageIndex;
}

//

/**
 * @summary Return name of stage for index `stageIndex`.
 * @param {Number} stageIndex Index of stage.
 * @funciton stageNameOf
 * @memberof module:Tools/mid/Stager.PublishCommandTest2#
*/

function stageNameOf( stageIndex )
{
  let stager = this;
  let stagaName = stageIndex;

  if( _.numberIs( stagaName ) )
  stagaName = stager.stageNames[ stagaName ];

  _.assert( _.strIs( stagaName ), () => 'Cant find stage name for stage index ' + stageIndex );
  _.assert( arguments.length === 1 );

  return stagaName;
}

//

/**
 * @summary Set or get specific state of all stages.
 * @param {String} stageName Name of stage.
 * @funciton stagesState
 * @memberof module:Tools/mid/Stager.PublishCommandTest2#
*/

function stagesState( stateName, value )
{
  let stager = this;
  let object = stager.object;
  let result = Object.create( null );

  _.assert( arguments.length === 1 || arguments.length === 2 );

  for( let stageIndex = 0 ; stageIndex < stager.stageNames.length ; stageIndex++ )
  {
    let stageName = stager.stageNames[ stageIndex ];
    let state = stager.stageState( stageIndex );

    _.assert( _.boolIs( state[ stateName ] ) );

    if( value !== undefined )
    state[ stateName ] = !!value;
    result[ stageName ] = state[ stateName ];

    stager.stageState( stageIndex, state );
  }

  return result;
}

//

/**
 * @summary Returns info about stages.
 * @funciton exportString
 * @memberof module:Tools/mid/Stager.PublishCommandTest2#
*/

function exportString()
{
  let stager = this;
  let result = '';

  for( let stageIndex = 0 ; stageIndex < stager.stageNames.length ; stageIndex++ )
  {
    let stageName = stager.stageNames[ stageIndex ];
    let state = stager.stageState( stageIndex );
    let consequence = stager.consequences[ stageIndex ];
    let failStr = consequence.errorsCount() ? ( ' - ' + 'fail' ) : '';
    let conStr = consequence.exportString({ verbosity : 1 });
    let stateStr = '';
    for( let s in state )
    stateStr += s[ 0 ] + s[ 1 ] + ':' + state[ s ] + ' ';
    result += stageName + ' : ' + stateStr + '- ' + conStr + failStr + '\n';
  }

  return result;
}

//

/**
 * @descriptionNeeded
 * @param {String} stageName Name of stage.
 * @param {Number} number Number of stage.
 * @funciton stageState
 * @memberof module:Tools/mid/Stager.PublishCommandTest2#
*/

function stageState( stage, state )
{
  let stager = this;
  let stageIndex = stager.stageIndexOf( stage );
  let currenStageIndex = stager.stageIndexOf( stager.currentStage );
  let begun = currenStageIndex > stageIndex || ( currenStageIndex === stageIndex && stager.currentPhase >= 1 );
  let ended = currenStageIndex > stageIndex || ( currenStageIndex === stageIndex && stager.currentPhase >= 3 );

  _.assert( arguments.length === 1 || arguments.length === 2 );

  if( state === undefined )
  {
    state = stager.object[ stager.stageNames[ stageIndex ] ];
    state = stager.stateToMap( state );
    state.begun = begun;
    state.ended = ended;
  }
  else
  {

    if( !state.begun || !state.ended )
    if( state.begun !== begun || state.ended !== ended )
    {
      _.assert
      (
        !state.begun
        , `Was attempt to set on state "begun" of stage ${stager.stageNameOf( stage )}. It should not happen directly.`
      );
      _.assert
      (
        !state.ended
        , `Was attempt to set on state "ended" of stage ${stager.stageNameOf( stage )}. It should not happen directly.`
      );
      if( currenStageIndex > stageIndex )
      {
        stager.currentStage = stager.stageNames[ stageIndex ];
        stager.currentPhase = 0;
      }
      begun = false;
      ended = false;
    }

    _.assert( state.begun === begun );
    _.assert( state.ended === ended );
    _.assert
    (
      !Object.isFrozen( stager.object )
      , () => 'Object is frozen, cant modify it : ' + _.toStrShort( stager.object )
    );

    let state2 = _.mapExtend( null, state );
    delete state2.begun;
    delete state2.ended;
    stager.object[ stager.stageNames[ stageIndex ] ] = stager.stateFromMap( state2 );
  }

  return state;
}


//

function stageStateSpecific_functor( stateName )
{

  return function stageStateSpecific( stage, value )
  {
    let stager = this;

    _.assert( arguments.length === 0 || arguments.length === 1 || arguments.length === 2 );

    if( stage === undefined )
    {
      debugger;
      let result = [];
      for( let stageIndex = 0 ; stageIndex < stager.stageNames.length ; stageIndex++ )
      {
        result[ stageIndex ] = stageStateSpecific.call( stager, stageIndex, value );
      }
      return result;
    }

    // if( stage === 'subModulesFormed' && !value && value !== undefined )
    // debugger;

    let state = stager.stageState( stage );

    if( value !== undefined )
    {
      _.assert( _.boolIs( state[ stateName ] ) );
      state[ stateName ] = !!value;
      stager.stageState( stage, state );
    }

    _.assert( _.boolIs( state[ stateName ] ) );
    return state[ stateName ];
  }

}

//

function stateToMap( src )
{
  let stager = this;
  return stager.stateMask.wordToMap( src );
}

//

function stateFromMap( src )
{
  let stager = this;
  return stager.stateMask.mapToWord( src );
}

//

function isValid()
{
  let stager = this;

  for( let stageIndex = 0 ; stageIndex < stager.stageNames.length ; stageIndex++ )
  {
    let state = stager.stageState( stageIndex );
    if( state.errored )
    return false;
  }

  return true;
}

//

function tick()
{
  let stager = this;
  let currenStageIndex = stager.stageIndexOf( stager.currentStage );
  let error;

  // if( stager.isFinited() )
  // debugger;
  if( Object.isFrozen( stager.object ) ) // xxx yyy
  // if( stager.isFinited() )
  return stager.consequences[ stager.consequences.length - 1 ];

  /* if begin a stage then return */

  if( stager.currentPhase === 1 )
  {
    _.assert( stager.running > 0 );
    return stager.consequences[ currenStageIndex ];
  }

  stager.running += 1;
  if( stager.running === 1 )
  {
    statusChange( `${stager.currentStage}.ticking`, 'begin', '' );
  }

  _.assert( stager.currentPhase === 0 || stager.currentPhase === 3 );
  if( stager.currentPhase === 3 )
  {
    if( currenStageIndex === stager.stageNames.length - 1 )
    return stager.consequences[ currenStageIndex ];
    currenStageIndex += 1;
    stager.currentStage = stager.stageNames[ currenStageIndex ];
    stager.currentPhase = 0;
  }

  // for( let stageIndex = 0 ; stageIndex < stager.stageNames.length ; stageIndex++ )
  for( let stageIndex = currenStageIndex ; stageIndex < stager.stageNames.length ; stageIndex++ )
  {
    let stageName = stager.stageNames[ stageIndex ];
    let state = stager.stageState( stageIndex );
    let consequence = stager.consequences[ stageIndex ];
    let onPerform = stager.onPerform[ stageIndex ];
    let onBegin = stager.onBegin[ stageIndex ];
    let onEnd = stager.onEnd[ stageIndex ];

    _.assert( !consequence.resourcesCount() || state.ended );
    _.assert( !state.ended );
    _.assert( stager.currentPhase === 0 );

    if( !state.ended )
    {

      _.assert( stager.stageIndexOf( stager.currentStage ) === stageIndex );

      if( state.begun || state.pausing )
      {
        end();
        return consequence;
      }

      if( state.errored )
      {
        _.assert( 0, 'not tested' );
      }

      if( !onPerform )
      onPerform = function() { return null }

      // if( !onPerform || state.skipping || state.performed )
      // onPerform = function() { return null }

      _.assert( stager.currentPhase === 0 );
      stager.currentPhase = 1;
      // state.begun = true;
      // stager.stageState( stageIndex, state );

      let prevConsequence = stager.consequences[ stageIndex-1 ];
      if( !prevConsequence )
      prevConsequence = new _.Consequence().take( null );

      return routineRun( onBegin, onPerform, onEnd, stageName, state, prevConsequence, consequence );
    }

  }

  return end();

  /* */

  function end()
  {
    stager.running -= 1;
    if( stager.running === 0 )
    {
      // if( stager.verbosity )
      // logger.log( 'stager.running end' );
      // statusChange( stageName, 'running', 'end' );
      statusChange( `${stager.currentStage}.ticking`, 'end', '' );
    }
    return stager.consequences[ stager.consequences.length - 1 ];
  }

  /* */

  function statusChange( stageName, stateName, status )
  {
    let name = stager.object.absoluteName || stager.object.qualifiedName || stager.object.name;
    let info = `stage:${stageName}.${stateName} ${name} running:${stager.running} status:${status}`;
    if( stager.verbosity )
    logger.log( info );
    stager.currentStatus = info;
  }

  /* */

  function routineRun( /* onBegin, onPerform, onEnd, stageName, state, prevConsequence, consequence */ )
  {

    let onBegin = arguments[ 0 ];
    let onPerform = arguments[ 1 ];
    let onEnd = arguments[ 2 ];
    let stageName = arguments[ 3 ];
    let state = arguments[ 4 ];
    let prevConsequence = arguments[ 5 ];
    let consequence = arguments[ 6 ];

    // stager.running += 1;

    statusChange( stageName, 'before', '' );

    prevConsequence = prevConsequence.split();

    prevConsequence.andTake( stager._ready );

    prevConsequence.finally( function stageBegin( err, arg )
    {
      if( onBegin === null )
      {
        if( err )
        throw err;
        return arg;
      }
      statusChange( stageName, 'begin', '' );
      try
      {
        let r = onBegin.call( stager.object );
        if( err )
        throw err;
        return r;
      }
      catch( err2 )
      {
        statusChange( stageName, 'begin', 'error' );
        err2 = _.err( err2, '\nError on begin of stage', stageName );
        if( err )
        throw err;
        throw err2;
      }
    });

    prevConsequence.then( function stagePeform( arg )
    {
      let state = stager.stageState( stageName );
      if( state.skipping || state.performed )
      return null;
      statusChange( stageName, 'perform', '' );
      try
      {
        return onPerform.call( stager.object );
      }
      catch( err )
      {
        statusChange( stageName, 'perform', 'error' );
        err = _.err( err, '\nError on perform of stage', stageName );
        throw err;
      }
    });

    prevConsequence.finally( function stageEnd1( err, arg )
    {

      if( err )
      {
        statusChange( stageName, 'end1', 'error' );
      }
      else if( state.skipping )
      {
        statusChange( stageName, 'end1', 'skip' );
      }
      else
      {
        statusChange( stageName, 'end1', '' );
      }

      error = error || err;
      let state2 = stager.stageState( stageName );
      state2.performed = ( !state.skipping || state.performed ) && !err;
      state2.errored = !!err;
      stager.stageState( stageName, state2 );

      _.assert( stager.currentPhase === 1 );
      stager.currentPhase = 2;

      // consequence.take( err, arg ); // yyy

      return arg || null;
    });

    prevConsequence.then( function stageEnd2( arg )
    {
      statusChange( stageName, 'end2', '' );
      if( onEnd === null )
      return arg;
      try
      {
        return onEnd.call( stager.object );
      }
      catch( err )
      {
        statusChange( stageName, 'end', 'error' );
        err = _.err( err, '\nError on end of stage', stageName );
        throw err;
      }
    });

    prevConsequence.finally( function stageFinally( err, arg )
    {

      if( err )
      {
        // debugger;
        statusChange( stageName, 'after2', 'error' );
        let state2 = stager.stageState( stageName );
        state2.performed = 0;
        state2.errored = 1;
        stager.stageState( stageName, state2 );
        error = error || err;
      }
      else
      {
        statusChange( stageName, 'after2', '' );
      }

      _.assert( stager.currentPhase === 2 );
      stager.currentPhase = 3;
      // stager.running -= 1;

      end();

      if( error )
      consequence.error( error ); // yyy
      else
      consequence.take( err, arg ); // yyy
      stager._ready.take( arg || null );
      stager.tick();

      if( err )
      throw err;
      return arg;
    });

    return consequence;
  }

} /* end of function tick */

// --
// relations
// --

let Composes =
{
  stageNames : null,
  consequences : null,
  verbosity : 0,
  stateMaskFields : null,
  onPerform : null,
  onBegin : null,
  onEnd : null,
  _ready : _.define.instanceOf( _.Consequence ),
}

let Aggregates =
{
}

let Associates =
{
  object : null,
}

let Restricts =
{
  currentStatus : null,
  currentStage : null,
  currentPhase : 0,
  stateMask : null,
  running : 0,
}

let Statics =
{
}

let Forbids =
{
  finals : 'finals',
  consequence : 'consequence',
  ready : 'ready',
}

let Accessors =
{
}

// --
// declare
// --

let Proto =
{

  // inter

  init,

  cancel,

  stageReset,
  stageError,
  stageConsequence,
  stageIndexOf,
  stageNameOf,
  stagesState,

  stageState,
  stageStateSkipping : stageStateSpecific_functor( 'skipping' ),
  stageStatePausing : stageStateSpecific_functor( 'pausing' ),
  stageStateBegun : stageStateSpecific_functor( 'begun' ),
  stageStateEnded : stageStateSpecific_functor( 'ended' ),
  stageStateErrored : stageStateSpecific_functor( 'errored' ),
  stageStatePerformed : stageStateSpecific_functor( 'performed' ),

  stateToMap,
  stateFromMap,

  isValid,
  tick,

  exportString,

  // relation

  Composes,
  Aggregates,
  Associates,
  Restricts,
  Statics,
  Forbids,
  Accessors,

}

_.classDeclare
({
  cls : Self,
  parent : Parent,
  extend : Proto,
});

_.Copyable.mixin( Self );
_[ Self.shortName ] = Self;
if( typeof module !== 'undefined' )
module[ 'exports' ] = _global_.wTools;

})();
