// Retrieve
var MongoClient = require('mongodb').MongoClient;
var util = require('util');

// Connect to the db
MongoClient.connect('mongodb://localhost:27017/query_composer_development', function(err, db) {
  if(err) { return console.dir(err); }

  db.collection('queries', null,
    function(err, queries)
    {
      if(err) { throw err; }

      //fetch the retro query excution
      //****************************************************************************
      queries.find({title:'Retro-PDC-053'}).toArray(
        function(err, retroPDC053Queries)
        {
          if(err) { throw err; }

          if(retroPDC053Queries.length != 1)
          {
            throw new Error('Not one and only one query with title for Retro-PDC-053');
          }

          var retroPDC053 = retroPDC053Queries[0];

          if(retroPDC053.executions.length != 1)
          {
            throw new Error('Not one and only one execution for Retro-PDC-053');
          }

          retroPDC053.executions = retroPDC053.executions.sort(
            function(a,b)
            {
              return a.time > b.time ? 1 : b.time > a.time ? -1 : 0;
            }
          );

          var retroPDC053Execution = retroPDC053.executions[0];

          //****************************************************************************

          //fetch query executions
          //****************************************************************************
          var pdc053Queries = queries.find({title:'PDC-053'}).toArray(
            function(err, pdc053Queries)
            {
              if(err) { throw err; }

              if(pdc053Queries.length != 1)
              {
                throw new Error('Not one and only one query with title for PDC-053');
              }

              var pdc053 = pdc053Queries[0];

              var pdc053Executions = pdc053.executions;
              //****************************************************************************

              //fetch retro retroResults
              //****************************************************************************
              var retroResults = retroPDC053Execution.aggregate_result;
              //****************************************************************************

              //build simulated executions
              //****************************************************************************
              var simulatedExecutions = {};

              for( var key in retroResults)
              {
                if( !retroResults.hasOwnProperty(key))
                {
                  continue;
                }

                var execution = JSON.parse(key);

                var date = execution.date/1000;//convert to seconds
                var simulatedExecution;

                if( !simulatedExecutions[date] )
                {
                  var aggregate_result = {};
                  var ar_key;

                  if(execution.value === 'numerator')
                  {
                    ar_key = 'numerator_' + execution.pid;
                    aggregate_result[ar_key] = retroResults[key];
                  }
                  else if(execution.value === 'denominator')
                  {
                    ar_key = 'denominator_' + execution.pid;
                    aggregate_result[ar_key] = retroResults[key];
                  }
                  else {
                    throw new Error('key did not have value in ["numerator", "denominator"]');
                  }

                  simulatedExecution = {'_id':retroPDC053Execution._id,
                                            'aggregate_result':aggregate_result,
                                            'notification':null,
                                            'time':date
                                            };

                  simulatedExecutions[date] = simulatedExecution;
                }
                else
                {
                  simulatedExecution = simulatedExecutions[date];
                  if(!simulatedExecution)
                  {
                    throw new Error('simulatedExecution evaluted to false');
                  }
			
		  console.log('execution.value: ' + execution.value);
	          console.log('aggresult: ' + util.inspect(simulatedExecution.aggregate_result));
		  console.log('den_id: ' + simulatedExecution.aggregate_result['denominator_' + execution.pid]);

                  if(execution.value === 'numerator' &&
                    simulatedExecution.aggregate_result['denominator_' + execution.pid] !== undefined &&
                    simulatedExecution.aggregate_result['denominator_' + execution.pid] !== null
                    )
                  {
                    simulatedExecution.aggregate_result['numerator_' + execution.pid] = retroResults[key];
                  }
                  else if(execution.value === 'denominator' &&
                    simulatedExecution.aggregate_result['numerator_' + execution.pid] !== undefined &&
                    simulatedExecution.aggregate_result['numerator_' + execution.pid] !== null )
                  {
                    simulatedExecution.aggregate_result['denominator_' + execution.pid] = retroResults[key];
                  }
                  else
                  {
                    throw new Error("no match for date: " + date);
                  }

                  simulatedExecution.aggregate_result.simulated = true;
                }
              }
              //****************************************************************************

              //console.log("****Retro Execution****");
              //console.log(retroPDC053Execution);

              //console.log("****pdc053Executions****");
              //console.log(pdc053Executions);

              //add the simulated executions to the execution List
              //****************************************************************************
              for( var se in simulatedExecutions)
              {
                if( !simulatedExecutions.hasOwnProperty(se))
                {
                  continue;
                }

                pdc053Executions.push( simulatedExecutions[se] );
              }
              //****************************************************************************

              //update the query with the retro results
              //****************************************************************************

              queries.updateOne({title:'PDC-053'}, {$set:{executions:pdc053Executions}}, {upsert:true},
                  function(err, result)
                  {
                    if(err)
                    {
                      throw new Error(err);
                    }

                    queries.find({title:'PDC-053'}).toArray(
                      function(err, queries)
                      {
                        if(err)
                        {
                          throw new Error(err);
                        }

                        if(queries.length != 1)
                        {
                          throw new Error('not one and only one query with title pdc-053');
                        }

                        var query = queries[0];

                        //console.log("****revised pdc053Executions****");
                        console.log(query.executions);
                      }
                    );
                  });

              //****************************************************************************
            });

        });
    }
  );

  console.log('done!');
});
